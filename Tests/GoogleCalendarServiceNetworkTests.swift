import XCTest
@testable import Maurice

// MARK: - URLProtocol stub

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Capture, resolving httpBody from the original request (URLProtocol wraps it and strips body).
        var captured = request
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            captured.httpBody = Self.readAll(from: stream)
        }
        Self.capturedRequests.append(captured)

        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "StubURLProtocol", code: -1))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func readAll(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    static func reset() {
        handler = nil
        capturedRequests = []
    }
}

// MARK: - Tests

final class GoogleCalendarServiceNetworkTests: XCTestCase {
    private var previousSession: URLSession!

    override func setUp() {
        super.setUp()
        previousSession = GoogleCalendarService.urlSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        GoogleCalendarService.urlSession = URLSession(configuration: config)
        StubURLProtocol.reset()
    }

    override func tearDown() {
        GoogleCalendarService.urlSession = previousSession
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - exchangeCodeForTokens

    func testExchangeCodeForTokensSuccess() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let body: [String: Any] = [
                "access_token": "at_123",
                "refresh_token": "rt_456",
                "expires_in": 3600
            ]
            let data = try JSONSerialization.data(withJSONObject: body)
            return (response, data)
        }

        let tokens = try await GoogleCalendarService.exchangeCodeForTokens(
            code: "auth_code", redirectURI: "http://127.0.0.1:1234"
        )

        XCTAssertEqual(tokens.accessToken, "at_123")
        XCTAssertEqual(tokens.refreshToken, "rt_456")
        XCTAssertGreaterThan(tokens.expiresAt, Date())
        XCTAssertLessThanOrEqual(tokens.expiresAt, Date().addingTimeInterval(3601))
    }

    func testExchangeCodeForTokensPostsToGoogleTokenEndpointWithFormBody() async throws {
        StubURLProtocol.handler = Self.validTokenResponse(_:)
        _ = try await GoogleCalendarService.exchangeCodeForTokens(
            code: "abc", redirectURI: "http://127.0.0.1:9999"
        )

        let request = try XCTUnwrap(StubURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://oauth2.googleapis.com/token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("code=abc"), "body=\(body)")
        XCTAssertTrue(body.contains("grant_type=authorization_code"), "body=\(body)")
        XCTAssertTrue(body.contains("redirect_uri=http://127.0.0.1:9999"), "body=\(body)")
    }

    func testExchangeCodeForTokensPercentEncodesSpecialCharacters() async throws {
        StubURLProtocol.handler = Self.validTokenResponse(_:)
        _ = try await GoogleCalendarService.exchangeCodeForTokens(
            code: "a+b&c=d e", redirectURI: "http://x"
        )

        let request = try XCTUnwrap(StubURLProtocol.capturedRequests.first)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("code=a%2Bb%26c%3Dd%20e"), "body=\(body)")
    }

    func testExchangeCodeForTokensThrowsWhenAccessTokenMissing() async {
        StubURLProtocol.handler = Self.jsonResponse([
            "refresh_token": "rt", "expires_in": 3600
        ])
        await assertThrows(expected: .tokenExchangeFailed) {
            _ = try await GoogleCalendarService.exchangeCodeForTokens(code: "c", redirectURI: "r")
        }
    }

    func testExchangeCodeForTokensThrowsWhenRefreshTokenMissing() async {
        StubURLProtocol.handler = Self.jsonResponse([
            "access_token": "at", "expires_in": 3600
        ])
        await assertThrows(expected: .tokenExchangeFailed) {
            _ = try await GoogleCalendarService.exchangeCodeForTokens(code: "c", redirectURI: "r")
        }
    }

    func testExchangeCodeForTokensThrowsWhenExpiresInMissing() async {
        StubURLProtocol.handler = Self.jsonResponse([
            "access_token": "at", "refresh_token": "rt"
        ])
        await assertThrows(expected: .tokenExchangeFailed) {
            _ = try await GoogleCalendarService.exchangeCodeForTokens(code: "c", redirectURI: "r")
        }
    }

    func testExchangeCodeForTokensThrowsForMalformedJSON() async {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("not-json".utf8))
        }
        do {
            _ = try await GoogleCalendarService.exchangeCodeForTokens(code: "c", redirectURI: "r")
            XCTFail("expected throw")
        } catch {
            // Either a JSON error or tokenExchangeFailed — both acceptable.
        }
    }

    // MARK: - refreshAccessToken

    func testRefreshAccessTokenSuccess() async throws {
        StubURLProtocol.handler = Self.jsonResponse([
            "access_token": "new_at", "expires_in": 7200
        ])

        let tokens = try await GoogleCalendarService.refreshAccessToken(refreshToken: "old_rt")

        XCTAssertEqual(tokens.accessToken, "new_at")
        XCTAssertEqual(tokens.refreshToken, "old_rt", "refresh token should be preserved from input")
        XCTAssertGreaterThan(tokens.expiresAt, Date().addingTimeInterval(7000))
    }

    func testRefreshAccessTokenPostsToTokenEndpointWithFormBody() async throws {
        StubURLProtocol.handler = Self.jsonResponse([
            "access_token": "new_at", "expires_in": 3600
        ])

        _ = try await GoogleCalendarService.refreshAccessToken(refreshToken: "rt_xyz")

        let request = try XCTUnwrap(StubURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://oauth2.googleapis.com/token")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("refresh_token=rt_xyz"), "body=\(body)")
        XCTAssertTrue(body.contains("grant_type=refresh_token"), "body=\(body)")
    }

    func testRefreshAccessTokenThrowsWhenAccessTokenMissing() async {
        StubURLProtocol.handler = Self.jsonResponse(["expires_in": 3600])
        await assertThrows(expected: .refreshFailed) {
            _ = try await GoogleCalendarService.refreshAccessToken(refreshToken: "rt")
        }
    }

    func testRefreshAccessTokenThrowsWhenExpiresInMissing() async {
        StubURLProtocol.handler = Self.jsonResponse(["access_token": "at"])
        await assertThrows(expected: .refreshFailed) {
            _ = try await GoogleCalendarService.refreshAccessToken(refreshToken: "rt")
        }
    }

    // MARK: - fetchUpcomingEvents

    func testFetchUpcomingEventsReturnsParsedEvents() async throws {
        let now = Date()
        let start1 = now.addingTimeInterval(600)
        let start2 = now.addingTimeInterval(7200)
        StubURLProtocol.handler = Self.jsonResponse([
            "items": [
                Self.item(id: "a", summary: "Alpha", start: start1, end: start1.addingTimeInterval(1800)),
                Self.item(id: "b", summary: "Beta", start: start2, end: start2.addingTimeInterval(1800))
            ]
        ])

        let events = try await GoogleCalendarService.fetchUpcomingEvents(accessToken: "tok")

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.map(\.id), ["a", "b"])
        XCTAssertEqual(events.map(\.summary), ["Alpha", "Beta"])
    }

    func testFetchUpcomingEventsSendsBearerHeaderAndQueryString() async throws {
        StubURLProtocol.handler = Self.jsonResponse(["items": []])

        _ = try await GoogleCalendarService.fetchUpcomingEvents(accessToken: "my_token", limit: 3)

        let request = try XCTUnwrap(StubURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer my_token")
        let url = try XCTUnwrap(request.url)
        XCTAssertTrue(url.absoluteString.hasPrefix("https://www.googleapis.com/calendar/v3/calendars/primary/events"))
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "maxResults" }?.value, "23")
        XCTAssertEqual(query.first { $0.name == "singleEvents" }?.value, "true")
        XCTAssertEqual(query.first { $0.name == "orderBy" }?.value, "startTime")
        XCTAssertNotNil(query.first { $0.name == "timeMin" }?.value)
    }

    func testFetchUpcomingEventsFiltersEventsThatAlreadyEnded() async throws {
        let now = Date()
        let endedStart = now.addingTimeInterval(-7200)
        let endedEnd = now.addingTimeInterval(-3600)
        let ongoingStart = now.addingTimeInterval(-600)
        let ongoingEnd = now.addingTimeInterval(1800)
        StubURLProtocol.handler = Self.jsonResponse([
            "items": [
                Self.item(id: "ended", summary: "Ended", start: endedStart, end: endedEnd),
                Self.item(id: "ongoing", summary: "Ongoing", start: ongoingStart, end: ongoingEnd)
            ]
        ])

        let events = try await GoogleCalendarService.fetchUpcomingEvents(accessToken: "t")

        XCTAssertEqual(events.map(\.id), ["ongoing"])
    }

    func testFetchUpcomingEventsRespectsLimit() async throws {
        let now = Date()
        let items = (0..<10).map { i -> [String: Any] in
            let start = now.addingTimeInterval(TimeInterval(i * 3600 + 600))
            return Self.item(id: "e\(i)", summary: "E\(i)", start: start, end: start.addingTimeInterval(1800))
        }
        StubURLProtocol.handler = Self.jsonResponse(["items": items])

        let events = try await GoogleCalendarService.fetchUpcomingEvents(accessToken: "t", limit: 3)

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map(\.id), ["e0", "e1", "e2"])
    }

    func testFetchUpcomingEventsReturnsEmptyForNoItems() async throws {
        StubURLProtocol.handler = Self.jsonResponse([:])

        let events = try await GoogleCalendarService.fetchUpcomingEvents(accessToken: "t")

        XCTAssertTrue(events.isEmpty)
    }

    func testFetchUpcomingEventsSkipsUnparseableItems() async throws {
        let now = Date()
        let start = now.addingTimeInterval(600)
        StubURLProtocol.handler = Self.jsonResponse([
            "items": [
                ["id": "no_summary", "start": ["dateTime": "\(start.iso8601)"]],
                Self.item(id: "good", summary: "OK", start: start, end: start.addingTimeInterval(1800))
            ]
        ])

        let events = try await GoogleCalendarService.fetchUpcomingEvents(accessToken: "t")

        XCTAssertEqual(events.map(\.id), ["good"])
    }

    // MARK: - fetchUserEmail

    func testFetchUserEmailReturnsEmail() async throws {
        StubURLProtocol.handler = Self.jsonResponse(["email": "user@example.com"])

        let email = try await GoogleCalendarService.fetchUserEmail(accessToken: "t")

        XCTAssertEqual(email, "user@example.com")
    }

    func testFetchUserEmailSendsBearerHeaderToUserinfoEndpoint() async throws {
        StubURLProtocol.handler = Self.jsonResponse(["email": "x@y.com"])

        _ = try await GoogleCalendarService.fetchUserEmail(accessToken: "my_token")

        let request = try XCTUnwrap(StubURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://www.googleapis.com/oauth2/v2/userinfo")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer my_token")
    }

    func testFetchUserEmailThrowsWhenEmailMissing() async {
        StubURLProtocol.handler = Self.jsonResponse(["not_email": "oops"])
        await assertThrows(expected: .emailFetchFailed) {
            _ = try await GoogleCalendarService.fetchUserEmail(accessToken: "t")
        }
    }

    // MARK: - Helpers

    private static func jsonResponse(_ body: [String: Any]) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        return { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            let data = try JSONSerialization.data(withJSONObject: body)
            return (response, data)
        }
    }

    private static func validTokenResponse(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        let data = try JSONSerialization.data(withJSONObject: [
            "access_token": "at", "refresh_token": "rt", "expires_in": 3600
        ])
        return (response, data)
    }

    private static func item(id: String, summary: String, start: Date, end: Date) -> [String: Any] {
        [
            "id": id,
            "summary": summary,
            "start": ["dateTime": start.iso8601],
            "end": ["dateTime": end.iso8601]
        ]
    }

    private func assertThrows(
        expected: GoogleCalendarError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as GoogleCalendarError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("expected GoogleCalendarError.\(expected), got \(error)", file: file, line: line)
        }
    }
}

private extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}

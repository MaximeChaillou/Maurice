import XCTest
@testable import Maurice

final class MockCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    var oauthTokens: GoogleTokens?
    var oauthError: Error?
    var userEmail = "test@example.com"
    var emailError: Error?
    var upcomingEvents: [GoogleCalendarEvent] = []
    var upcomingError: Error?
    var currentEvent: GoogleCalendarEvent?
    var currentEventError: Error?
    var refreshedTokens: GoogleTokens?
    var refreshError: Error?

    var startOAuthFlowCallCount = 0
    var fetchEmailCallCount = 0
    var fetchUpcomingCallCount = 0
    var fetchCurrentCallCount = 0
    var refreshCallCount = 0

    func startOAuthFlow() async throws -> GoogleTokens {
        startOAuthFlowCallCount += 1
        if let error = oauthError { throw error }
        return oauthTokens ?? GoogleTokens(
            accessToken: "access", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
    }

    func fetchUserEmail(accessToken: String) async throws -> String {
        fetchEmailCallCount += 1
        if let error = emailError { throw error }
        return userEmail
    }

    func fetchUpcomingEvents(accessToken: String, limit: Int) async throws -> [GoogleCalendarEvent] {
        fetchUpcomingCallCount += 1
        if let error = upcomingError { throw error }
        return upcomingEvents
    }

    func fetchCurrentEvent(accessToken: String) async throws -> GoogleCalendarEvent? {
        fetchCurrentCallCount += 1
        if let error = currentEventError { throw error }
        return currentEvent
    }

    func refreshAccessToken(refreshToken: String) async throws -> GoogleTokens {
        refreshCallCount += 1
        if let error = refreshError { throw error }
        return refreshedTokens ?? GoogleTokens(
            accessToken: "refreshed-access", refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(3600)
        )
    }
}

final class MockTokenStore: TokenStoreProtocol, @unchecked Sendable {
    var storedTokens: GoogleTokens?
    var saveCallCount = 0
    var clearCallCount = 0

    func save(_ tokens: GoogleTokens) {
        saveCallCount += 1
        storedTokens = tokens
    }

    func load() -> GoogleTokens? {
        storedTokens
    }

    func clear() {
        clearCallCount += 1
        storedTokens = nil
    }
}

private enum TestCalendarError: LocalizedError {
    case failed
    var errorDescription: String? { "Calendar error" }
}

@MainActor
final class GoogleCalendarViewModelTests: XCTestCase {

    // MARK: - Init / loadConnectionState

    func testInitWithNoTokensIsDisconnected() {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        XCTAssertFalse(vm.isConnected)
        XCTAssertNil(vm.connectedEmail)
    }

    func testInitWithValidTokensIsConnected() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        XCTAssertTrue(vm.isConnected)

        // Wait for email fetch
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(vm.connectedEmail, "test@example.com")
    }

    func testInitWithExpiredTokensRefreshes() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "expired", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-100)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        XCTAssertTrue(vm.isConnected)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(service.refreshCallCount, 1)
        XCTAssertEqual(store.saveCallCount, 1)
        XCTAssertEqual(vm.connectedEmail, "test@example.com")
    }

    func testInitWithExpiredTokensAndRefreshFailureDisconnects() async throws {
        let service = MockCalendarService()
        service.refreshError = TestCalendarError.failed
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "expired", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-100)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(vm.isConnected)
        XCTAssertNil(vm.connectedEmail)
    }

    // MARK: - connect

    func testConnectSuccess() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        vm.connect()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(vm.isConnected)
        XCTAssertEqual(vm.connectedEmail, "test@example.com")
        XCTAssertFalse(vm.isConnecting)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(store.saveCallCount, 1)
    }

    func testConnectFailureSetsError() async throws {
        let service = MockCalendarService()
        service.oauthError = TestCalendarError.failed
        let store = MockTokenStore()

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        vm.connect()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(vm.isConnected)
        XCTAssertFalse(vm.isConnecting)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testConnectWhileConnectingDoesNothing() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        vm.isConnecting = true
        vm.connect()

        try await Task.sleep(for: .milliseconds(200))

        // startOAuthFlow should not have been called
        XCTAssertEqual(service.startOAuthFlowCallCount, 0)
    }

    // MARK: - disconnect

    func testDisconnectClearsState() {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        vm.disconnect()

        XCTAssertFalse(vm.isConnected)
        XCTAssertNil(vm.connectedEmail)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(store.clearCallCount, 1)
    }

    // MARK: - upcomingEvents

    func testUpcomingEventsReturnsFetchedEvents() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let event = GoogleCalendarEvent(
            id: "1", summary: "Meeting", start: Date(), end: Date().addingTimeInterval(3600),
            attendees: []
        )
        service.upcomingEvents = [event]

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        let events = await vm.upcomingEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.summary, "Meeting")
    }

    func testUpcomingEventsReturnsEmptyWhenNoTokens() async {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        let events = await vm.upcomingEvents()

        XCTAssertTrue(events.isEmpty)
    }

    func testUpcomingEventsCachesResults() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        service.upcomingEvents = [GoogleCalendarEvent(
            id: "1", summary: "Cached", start: Date(), end: Date().addingTimeInterval(3600),
            attendees: []
        )]

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        _ = await vm.upcomingEvents()
        _ = await vm.upcomingEvents()

        // Should only fetch once due to cache
        XCTAssertEqual(service.fetchUpcomingCallCount, 1)
    }

    // MARK: - currentEvent

    func testCurrentEventReturnsFetchedEvent() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        service.currentEvent = GoogleCalendarEvent(
            id: "1", summary: "Now", start: Date(), end: Date().addingTimeInterval(3600),
            attendees: []
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        let event = await vm.currentEvent()

        XCTAssertEqual(event?.summary, "Now")
    }

    func testCurrentEventReturnsNilWhenNoTokens() async {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        let event = await vm.currentEvent()

        XCTAssertNil(event)
    }

    func testCurrentEventCachesResults() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        _ = await vm.currentEvent()
        _ = await vm.currentEvent()

        XCTAssertEqual(service.fetchCurrentCallCount, 1)
    }

    func testCurrentEventCachesNilResult() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        service.currentEvent = nil

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        let event1 = await vm.currentEvent()
        let event2 = await vm.currentEvent()

        XCTAssertNil(event1)
        XCTAssertNil(event2)
        XCTAssertEqual(service.fetchCurrentCallCount, 1)
    }

    // MARK: - validTokens

    func testValidTokensReturnsNilWhenNoTokens() async {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        let tokens = await vm.validTokens()

        XCTAssertNil(tokens)
    }

    func testValidTokensReturnsValidTokensDirectly() async {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        let tokens = await vm.validTokens()

        XCTAssertEqual(tokens?.accessToken, "valid")
        XCTAssertEqual(service.refreshCallCount, 0)
    }

    func testValidTokensRefreshesExpiredTokens() async {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "expired", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-100)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)
        // Wait for init's loadConnectionState to finish
        try? await Task.sleep(for: .milliseconds(300))

        let tokens = await vm.validTokens()

        XCTAssertEqual(tokens?.accessToken, "refreshed-access")
    }

    func testValidTokensReturnsNilWhenRefreshFails() async {
        let service = MockCalendarService()
        service.refreshError = TestCalendarError.failed
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "expired", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-100)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)
        // Wait for init's loadConnectionState
        try? await Task.sleep(for: .milliseconds(300))

        let tokens = await vm.validTokens()

        XCTAssertNil(tokens)
    }

    // MARK: - Email fetch failure in init

    func testInitWithValidTokensButEmailFetchFailureStaysConnected() async throws {
        let service = MockCalendarService()
        service.emailError = TestCalendarError.failed
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = GoogleCalendarViewModel(calendarService: service, tokenStore: store)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(vm.isConnected)
        XCTAssertNil(vm.connectedEmail)
    }
}

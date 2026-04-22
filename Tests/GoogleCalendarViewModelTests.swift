import XCTest
@testable import Maurice

final class MockCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    var oauthTokens: GoogleTokens?
    var oauthError: Error?
    var userEmail = "test@example.com"
    var emailError: Error?
    var upcomingEvents: [GoogleCalendarEvent] = []
    var upcomingError: Error?
    var refreshedTokens: GoogleTokens?
    var refreshError: Error?

    var startOAuthFlowCallCount = 0
    var fetchEmailCallCount = 0
    var fetchUpcomingCallCount = 0
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

    private func makeViewModel(
        service: MockCalendarService,
        store: MockTokenStore,
        refreshInterval: TimeInterval = 3600
    ) -> GoogleCalendarViewModel {
        GoogleCalendarViewModel(
            calendarService: service,
            tokenStore: store,
            refreshInterval: refreshInterval
        )
    }

    // MARK: - Init / loadConnectionState

    func testInitWithNoTokensIsDisconnected() {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = makeViewModel(service: service, store: store)

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

        let vm = makeViewModel(service: service, store: store)

        XCTAssertTrue(vm.isConnected)

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

        let vm = makeViewModel(service: service, store: store)

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

        let vm = makeViewModel(service: service, store: store)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(vm.isConnected)
        XCTAssertNil(vm.connectedEmail)
    }

    // MARK: - connect

    func testConnectSuccess() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = makeViewModel(service: service, store: store)

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

        let vm = makeViewModel(service: service, store: store)

        vm.connect()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(vm.isConnected)
        XCTAssertFalse(vm.isConnecting)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testConnectWhileConnectingDoesNothing() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = makeViewModel(service: service, store: store)

        vm.isConnecting = true
        vm.connect()

        try await Task.sleep(for: .milliseconds(200))

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

        let vm = makeViewModel(service: service, store: store)
        vm.upcomingEvents = [GoogleCalendarEvent(
            id: "1", summary: "X", start: Date(), end: Date().addingTimeInterval(3600),
            attendees: []
        )]

        vm.disconnect()

        XCTAssertFalse(vm.isConnected)
        XCTAssertNil(vm.connectedEmail)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.upcomingEvents.isEmpty)
        XCTAssertNil(vm.lastRefreshDate)
        XCTAssertEqual(store.clearCallCount, 1)
    }

    // MARK: - Auto-refresh

    func testAutoRefreshPopulatesUpcomingEventsOnInit() async throws {
        let service = MockCalendarService()
        service.upcomingEvents = [GoogleCalendarEvent(
            id: "1", summary: "Meeting", start: Date().addingTimeInterval(600),
            end: Date().addingTimeInterval(4200), attendees: []
        )]
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = makeViewModel(service: service, store: store)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.upcomingEvents.count, 1)
        XCTAssertEqual(vm.upcomingEvents.first?.summary, "Meeting")
        XCTAssertNotNil(vm.lastRefreshDate)
    }

    func testAutoRefreshRepeatsOnInterval() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = makeViewModel(service: service, store: store, refreshInterval: 0.1)
        _ = vm

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertGreaterThanOrEqual(service.fetchUpcomingCallCount, 3)
    }

    func testDisconnectStopsAutoRefresh() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = makeViewModel(service: service, store: store, refreshInterval: 0.1)

        try await Task.sleep(for: .milliseconds(250))
        let beforeDisconnect = service.fetchUpcomingCallCount
        XCTAssertGreaterThan(beforeDisconnect, 0)

        vm.disconnect()

        try await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(service.fetchUpcomingCallCount, beforeDisconnect)
    }

    func testConnectStartsAutoRefresh() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = makeViewModel(service: service, store: store, refreshInterval: 0.1)

        vm.connect()
        try await Task.sleep(for: .milliseconds(400))

        XCTAssertTrue(vm.isConnected)
        XCTAssertGreaterThan(service.fetchUpcomingCallCount, 0)
    }

    // MARK: - Derived accessors

    func testImminentEventReturnsFutureEventWithinWindow() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let now = Date()
        let soon = GoogleCalendarEvent(
            id: "1", summary: "Soon", start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60), attendees: []
        )
        let later = GoogleCalendarEvent(
            id: "2", summary: "Later", start: now.addingTimeInterval(120 * 60),
            end: now.addingTimeInterval(180 * 60), attendees: []
        )
        service.upcomingEvents = [soon, later]

        let vm = makeViewModel(service: service, store: store)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.imminentEvent(within: 60, now: now)?.summary, "Soon")
        XCTAssertNil(vm.imminentEvent(within: 5, now: now))
    }

    func testImminentEventSkipsOngoingEvents() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let now = Date()
        let ongoing = GoogleCalendarEvent(
            id: "1", summary: "Ongoing", start: now.addingTimeInterval(-10 * 60),
            end: now.addingTimeInterval(20 * 60), attendees: []
        )
        let next = GoogleCalendarEvent(
            id: "2", summary: "Next", start: now.addingTimeInterval(30 * 60),
            end: now.addingTimeInterval(60 * 60), attendees: []
        )
        service.upcomingEvents = [ongoing, next]

        let vm = makeViewModel(service: service, store: store)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.imminentEvent(within: 60, now: now)?.summary, "Next")
    }

    func testCurrentEventReturnsOngoingEvent() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let now = Date()
        let ongoing = GoogleCalendarEvent(
            id: "1", summary: "Ongoing", start: now.addingTimeInterval(-10 * 60),
            end: now.addingTimeInterval(20 * 60), attendees: []
        )
        service.upcomingEvents = [ongoing]

        let vm = makeViewModel(service: service, store: store)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.currentEvent(now: now)?.summary, "Ongoing")
    }

    func testCurrentEventReturnsEventStartingWithinFiveMinutes() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let now = Date()
        let soon = GoogleCalendarEvent(
            id: "1", summary: "Soon", start: now.addingTimeInterval(3 * 60),
            end: now.addingTimeInterval(30 * 60), attendees: []
        )
        service.upcomingEvents = [soon]

        let vm = makeViewModel(service: service, store: store)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.currentEvent(now: now)?.summary, "Soon")
    }

    func testCurrentEventReturnsNilWhenEventTooFarAway() async throws {
        let service = MockCalendarService()
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let now = Date()
        let later = GoogleCalendarEvent(
            id: "1", summary: "Later", start: now.addingTimeInterval(30 * 60),
            end: now.addingTimeInterval(60 * 60), attendees: []
        )
        service.upcomingEvents = [later]

        let vm = makeViewModel(service: service, store: store)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertNil(vm.currentEvent(now: now))
    }

    // MARK: - Refresh error handling

    func testRefreshErrorDoesNotCrashAndKeepsPreviousEvents() async throws {
        let service = MockCalendarService()
        let existing = GoogleCalendarEvent(
            id: "1", summary: "First", start: Date().addingTimeInterval(600),
            end: Date().addingTimeInterval(4200), attendees: []
        )
        service.upcomingEvents = [existing]
        let store = MockTokenStore()
        store.storedTokens = GoogleTokens(
            accessToken: "valid", refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let vm = makeViewModel(service: service, store: store, refreshInterval: 0.1)

        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(vm.upcomingEvents.count, 1)

        service.upcomingError = TestCalendarError.failed

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(vm.upcomingEvents.count, 1)
        XCTAssertEqual(vm.upcomingEvents.first?.summary, "First")
    }

    // MARK: - validTokens

    func testValidTokensReturnsNilWhenNoTokens() async {
        let service = MockCalendarService()
        let store = MockTokenStore()

        let vm = makeViewModel(service: service, store: store)

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

        let vm = makeViewModel(service: service, store: store)

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

        let vm = makeViewModel(service: service, store: store)
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

        let vm = makeViewModel(service: service, store: store)
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

        let vm = makeViewModel(service: service, store: store)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(vm.isConnected)
        XCTAssertNil(vm.connectedEmail)
    }
}

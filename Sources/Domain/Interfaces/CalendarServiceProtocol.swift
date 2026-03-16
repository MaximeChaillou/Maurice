import Foundation

protocol CalendarServiceProtocol: Sendable {
    func startOAuthFlow() async throws -> GoogleTokens
    func fetchUserEmail(accessToken: String) async throws -> String
    func fetchUpcomingEvents(accessToken: String, limit: Int) async throws -> [GoogleCalendarEvent]
    func fetchCurrentEvent(accessToken: String) async throws -> GoogleCalendarEvent?
    func refreshAccessToken(refreshToken: String) async throws -> GoogleTokens
}

protocol TokenStoreProtocol: Sendable {
    func save(_ tokens: GoogleTokens)
    func load() -> GoogleTokens?
    func clear()
}

// MARK: - Default conformances

struct DefaultCalendarService: CalendarServiceProtocol {
    func startOAuthFlow() async throws -> GoogleTokens {
        try await GoogleCalendarService.startOAuthFlow()
    }

    func fetchUserEmail(accessToken: String) async throws -> String {
        try await GoogleCalendarService.fetchUserEmail(accessToken: accessToken)
    }

    func fetchUpcomingEvents(accessToken: String, limit: Int) async throws -> [GoogleCalendarEvent] {
        try await GoogleCalendarService.fetchUpcomingEvents(accessToken: accessToken, limit: limit)
    }

    func fetchCurrentEvent(accessToken: String) async throws -> GoogleCalendarEvent? {
        try await GoogleCalendarService.fetchCurrentEvent(accessToken: accessToken)
    }

    func refreshAccessToken(refreshToken: String) async throws -> GoogleTokens {
        try await GoogleCalendarService.refreshAccessToken(refreshToken: refreshToken)
    }
}

struct DefaultTokenStore: TokenStoreProtocol {
    func save(_ tokens: GoogleTokens) {
        GoogleOAuthTokenStore.save(tokens)
    }

    func load() -> GoogleTokens? {
        GoogleOAuthTokenStore.load()
    }

    func clear() {
        GoogleOAuthTokenStore.clear()
    }
}

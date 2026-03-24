import Foundation
import Observation

@Observable
@MainActor
final class GoogleCalendarViewModel {
    var isConnected = false
    var connectedEmail: String?
    var isConnecting = false
    var errorMessage: String?

    private var cachedUpcoming: [GoogleCalendarEvent]?
    private var cachedUpcomingDate: Date?
    private var cachedCurrent: GoogleCalendarEvent??
    private var cachedCurrentDate: Date?
    private let cacheDuration: TimeInterval = 60

    private let calendarService: CalendarServiceProtocol
    private let tokenStore: TokenStoreProtocol

    init(
        calendarService: CalendarServiceProtocol = DefaultCalendarService(),
        tokenStore: TokenStoreProtocol = DefaultTokenStore()
    ) {
        self.calendarService = calendarService
        self.tokenStore = tokenStore
        loadConnectionState()
    }

    func connect() {
        guard !isConnecting else { return }
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let tokens = try await calendarService.startOAuthFlow()
                tokenStore.save(tokens)

                let email = try await calendarService.fetchUserEmail(accessToken: tokens.accessToken)
                connectedEmail = email
                isConnected = true
            } catch {
                IssueLogger.log(.error, "Google Calendar OAuth connection failed", error: error)
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }

    func disconnect() {
        tokenStore.clear()
        isConnected = false
        connectedEmail = nil
        errorMessage = nil
    }

    func upcomingEvents(limit: Int = 5) async -> [GoogleCalendarEvent] {
        if let cached = cachedUpcoming, let date = cachedUpcomingDate,
           Date().timeIntervalSince(date) < cacheDuration {
            return cached
        }
        guard let tokens = await validTokens() else { return [] }
        let events: [GoogleCalendarEvent]
        do {
            events = try await calendarService.fetchUpcomingEvents(
                accessToken: tokens.accessToken, limit: limit
            )
        } catch {
            IssueLogger.log(.warning, "Failed to fetch upcoming calendar events", error: error)
            events = []
        }
        cachedUpcoming = events
        cachedUpcomingDate = Date()
        return events
    }

    func currentEvent() async -> GoogleCalendarEvent? {
        if let cached = cachedCurrent, let date = cachedCurrentDate,
           Date().timeIntervalSince(date) < cacheDuration {
            return cached
        }
        guard let tokens = await validTokens() else { return nil }
        let event: GoogleCalendarEvent?
        do {
            event = try await calendarService.fetchCurrentEvent(accessToken: tokens.accessToken)
        } catch {
            IssueLogger.log(.warning, "Failed to fetch current calendar event", error: error)
            event = nil
        }
        cachedCurrent = .some(event)
        cachedCurrentDate = Date()
        return event
    }

    func validTokens() async -> GoogleTokens? {
        guard var tokens = tokenStore.load() else { return nil }
        if tokens.expiresAt < Date() {
            do {
                tokens = try await calendarService.refreshAccessToken(refreshToken: tokens.refreshToken)
                tokenStore.save(tokens)
            } catch {
                IssueLogger.log(.warning, "Failed to refresh Google Calendar token", error: error)
                return nil
            }
        }
        return tokens
    }

    private func loadConnectionState() {
        guard var tokens = tokenStore.load() else {
            isConnected = false
            return
        }

        isConnected = true

        Task {
            // Refresh if expired
            if tokens.expiresAt < Date() {
                do {
                    tokens = try await calendarService.refreshAccessToken(refreshToken: tokens.refreshToken)
                    tokenStore.save(tokens)
                } catch {
                    IssueLogger.log(.error, "Google Calendar token refresh failed, disconnecting", error: error)
                    disconnect()
                    return
                }
            }

            do {
                connectedEmail = try await calendarService.fetchUserEmail(accessToken: tokens.accessToken)
            } catch {
                IssueLogger.log(.warning, "Failed to fetch Google account email", error: error)
            }
        }
    }
}

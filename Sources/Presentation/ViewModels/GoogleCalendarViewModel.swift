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
    private var connectTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

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

        connectTask = Task { [weak self] in
            guard let self else { return }
            do {
                let tokens = try await self.calendarService.startOAuthFlow()
                self.tokenStore.save(tokens)

                let email = try await self.calendarService.fetchUserEmail(accessToken: tokens.accessToken)
                self.connectedEmail = email
                self.isConnected = true
            } catch {
                IssueLogger.log(.error, "Google Calendar OAuth connection failed", error: error)
                self.errorMessage = error.localizedDescription
            }
            self.isConnecting = false
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

        loadTask = Task { [weak self] in
            guard let self else { return }
            // Refresh if expired
            if tokens.expiresAt < Date() {
                do {
                    tokens = try await self.calendarService.refreshAccessToken(refreshToken: tokens.refreshToken)
                    self.tokenStore.save(tokens)
                } catch {
                    IssueLogger.log(.error, "Google Calendar token refresh failed, disconnecting", error: error)
                    self.disconnect()
                    return
                }
            }

            do {
                self.connectedEmail = try await self.calendarService.fetchUserEmail(accessToken: tokens.accessToken)
            } catch {
                IssueLogger.log(.warning, "Failed to fetch Google account email", error: error)
            }
        }
    }
}

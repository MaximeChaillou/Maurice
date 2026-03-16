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
        let events = (try? await calendarService.fetchUpcomingEvents(
            accessToken: tokens.accessToken, limit: limit
        )) ?? []
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
        let event = try? await calendarService.fetchCurrentEvent(accessToken: tokens.accessToken)
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
                    disconnect()
                    return
                }
            }

            if let email = try? await calendarService.fetchUserEmail(accessToken: tokens.accessToken) {
                connectedEmail = email
            }
        }
    }
}

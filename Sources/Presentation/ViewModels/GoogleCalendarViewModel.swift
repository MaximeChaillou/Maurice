import Foundation
import Observation

@Observable
@MainActor
final class GoogleCalendarViewModel {
    var isConnected = false
    var connectedEmail: String?
    var isConnecting = false
    var errorMessage: String?

    var upcomingEvents: [GoogleCalendarEvent] = []
    var lastRefreshDate: Date?

    private let calendarService: CalendarServiceProtocol
    private let tokenStore: TokenStoreProtocol
    private let refreshInterval: TimeInterval
    private let upcomingLimit: Int
    private var connectTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(
        calendarService: CalendarServiceProtocol = DefaultCalendarService(),
        tokenStore: TokenStoreProtocol = DefaultTokenStore(),
        refreshInterval: TimeInterval = 60,
        upcomingLimit: Int = 5
    ) {
        self.calendarService = calendarService
        self.tokenStore = tokenStore
        self.refreshInterval = refreshInterval
        self.upcomingLimit = upcomingLimit
        loadConnectionState()
    }

    // MARK: - Connect / Disconnect

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
                self.startAutoRefresh()
            } catch {
                IssueLogger.log(.error, "Google Calendar OAuth connection failed", error: error)
                self.errorMessage = error.localizedDescription
            }
            self.isConnecting = false
        }
    }

    func disconnect() {
        stopAutoRefresh()
        tokenStore.clear()
        isConnected = false
        connectedEmail = nil
        errorMessage = nil
        upcomingEvents = []
        lastRefreshDate = nil
    }

    // MARK: - Derived event accessors

    func imminentEvent(within minutes: Int = 60, now: Date = Date()) -> GoogleCalendarEvent? {
        let horizon = now.addingTimeInterval(TimeInterval(minutes * 60))
        return upcomingEvents.first { $0.start > now && $0.start <= horizon }
    }

    func currentEvent(now: Date = Date()) -> GoogleCalendarEvent? {
        let soon = now.addingTimeInterval(5 * 60)
        return upcomingEvents.first { $0.start <= soon && $0.end > now }
    }

    // MARK: - Refresh

    func refresh() async {
        guard let tokens = await validTokens() else {
            upcomingEvents = []
            return
        }
        do {
            let events = try await calendarService.fetchUpcomingEvents(
                accessToken: tokens.accessToken, limit: upcomingLimit
            )
            upcomingEvents = events
            lastRefreshDate = Date()
        } catch {
            IssueLogger.log(.warning, "Failed to fetch upcoming calendar events", error: error)
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        let interval = refreshInterval
        refreshTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Tokens

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

            self.startAutoRefresh()
        }
    }
}

import AppKit
import Foundation
import Network

enum GoogleCalendarService {
    // MARK: - Configuration

    static var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
    }

    static var clientSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "GoogleClientSecret") as? String ?? ""
    }

    private static let scopes = [
        "https://www.googleapis.com/auth/calendar.events.readonly",
        "https://www.googleapis.com/auth/userinfo.email"
    ]

    // MARK: - OAuth Flow

    static func startOAuthFlow() async throws -> GoogleTokens {
        let port = try await startLocalServer()
        let redirectURI = "http://127.0.0.1:\(port)"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        let authURL = components.url!
        await MainActor.run {
            _ = NSWorkspace.shared.open(authURL)
        }

        let code = try await waitForAuthCode()
        stopLocalServer()

        return try await exchangeCodeForTokens(code: code, redirectURI: redirectURI)
    }

    // MARK: - Token Exchange & Refresh

    static func exchangeCodeForTokens(code: String, redirectURI: String) async throws -> GoogleTokens {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        request.httpBody = formEncodedBody([
            ("code", code),
            ("client_id", clientID),
            ("client_secret", clientSecret),
            ("redirect_uri", redirectURI),
            ("grant_type", "authorization_code")
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw GoogleCalendarError.tokenExchangeFailed
        }

        return GoogleTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    static func refreshAccessToken(refreshToken: String) async throws -> GoogleTokens {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        request.httpBody = formEncodedBody([
            ("refresh_token", refreshToken),
            ("client_id", clientID),
            ("client_secret", clientSecret),
            ("grant_type", "refresh_token")
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw GoogleCalendarError.refreshFailed
        }

        return GoogleTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    // MARK: - API Calls

    static func fetchCurrentEvent(accessToken: String) async throws -> GoogleCalendarEvent? {
        let now = Date()
        let fiveMinutesFromNow = now.addingTimeInterval(5 * 60)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: now.addingTimeInterval(-24 * 3600))),
            URLQueryItem(name: "timeMax", value: formatter.string(from: fiveMinutesFromNow)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let items = json["items"] as? [[String: Any]] ?? []

        // Collect all current/upcoming events, then pick the best match
        let candidates = items.compactMap { parseCalendarItem($0) }
            .filter { $0.start <= fiveMinutesFromNow && $0.end > now }
            .map { GoogleCalendarEvent(
                id: $0.id, summary: sanitizeFolderName($0.summary),
                start: $0.start, end: $0.end, attendees: $0.attendees
            ) }

        // Prefer the event with the closest start time to now
        return candidates
            .min { abs($0.start.timeIntervalSince(now)) < abs($1.start.timeIntervalSince(now)) }
    }

    static func fetchUpcomingEvents(accessToken: String, limit: Int = 5) async throws -> [GoogleCalendarEvent] {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: now)),
            URLQueryItem(name: "maxResults", value: "\(limit + 10)"),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let items = json["items"] as? [[String: Any]] ?? []

        return Array(items.compactMap { parseCalendarItem($0) }.prefix(limit))
    }

    static func fetchUserEmail(accessToken: String) async throws -> String {
        let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let email = json["email"] as? String else {
            throw GoogleCalendarError.emailFetchFailed
        }
        return email
    }

    // MARK: - Local HTTP Server

    nonisolated(unsafe) private static var listener: NWListener?
    nonisolated(unsafe) private static var authCodeContinuation: CheckedContinuation<String, Error>?

    private static func startLocalServer() async throws -> UInt16 {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener

        listener.newConnectionHandler = { connection in
            handleConnection(connection)
        }

        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let port = listener.port {
                        continuation.resume(returning: port.rawValue)
                    }
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .main)
        }
    }

    private static func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
            guard let data,
                  let request = String(data: data, encoding: .utf8),
                  let firstLine = request.components(separatedBy: "\r\n").first else {
                connection.cancel()
                return
            }

            // Parse GET /?code=xxx HTTP/1.1
            if let urlString = firstLine.components(separatedBy: " ").dropFirst().first,
               let components = URLComponents(string: urlString),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {

                let response = """
                HTTP/1.1 200 OK\r\n\
                Content-Type: text/html; charset=utf-8\r\n\
                Connection: close\r\n\
                \r\n\
                <html><body><h2>Connexion réussie !</h2>\
                <p>Vous pouvez fermer cet onglet et retourner à Maurice.</p></body></html>
                """
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })

                authCodeContinuation?.resume(returning: code)
                authCodeContinuation = nil
            } else {
                connection.cancel()
            }
        }
    }

    private static func waitForAuthCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            authCodeContinuation = continuation

            // Timeout after 120 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                if authCodeContinuation != nil {
                    authCodeContinuation?.resume(throwing: GoogleCalendarError.oauthTimeout)
                    authCodeContinuation = nil
                    stopLocalServer()
                }
            }
        }
    }

    private static func stopLocalServer() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Item Parsing

    static func parseCalendarItem(_ item: [String: Any]) -> GoogleCalendarEvent? {
        guard let summary = item["summary"] as? String,
              let id = item["id"] as? String,
              let startDict = item["start"] as? [String: Any],
              let endDict = item["end"] as? [String: Any] else { return nil }

        // Skip all-day events
        if startDict["date"] != nil { return nil }

        let organizerEmail = (item["organizer"] as? [String: Any])?["email"] as? String
        if organizerEmail == "invite@pictarine.com" { return nil }

        guard let start = parseEventDate(startDict),
              let end = parseEventDate(endDict) else { return nil }

        let attendees = parseAcceptedAttendees(item)
        return GoogleCalendarEvent(id: id, summary: summary, start: start, end: end, attendees: attendees)
    }

    // MARK: - Helpers

    static func parseEventDate(_ dict: [String: Any]) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        if let dateTime = dict["dateTime"] as? String {
            return formatter.date(from: dateTime)
        }
        // All-day events use "date" field (yyyy-MM-dd)
        if let dateStr = dict["date"] as? String {
            return DateFormatters.dayOnly.date(from: dateStr)
        }
        return nil
    }

    static func parseAcceptedAttendees(_ item: [String: Any]) -> [GoogleCalendarEvent.Attendee] {
        guard let attendees = item["attendees"] as? [[String: Any]] else { return [] }
        return attendees.compactMap { entry in
            guard let email = entry["email"] as? String,
                  let status = entry["responseStatus"] as? String,
                  status == "accepted" else { return nil }
            let name = entry["displayName"] as? String
            return GoogleCalendarEvent.Attendee(email: email, displayName: name)
        }
    }

    static func sanitizeFolderName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        return name.components(separatedBy: invalid).joined(separator: "-")
    }

    private static func formEncodedBody(_ params: [(String, String)]) -> Data? {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
        return params.map { key, value in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

enum GoogleCalendarError: LocalizedError {
    case tokenExchangeFailed
    case refreshFailed
    case emailFetchFailed
    case oauthTimeout

    var errorDescription: String? {
        switch self {
        case .tokenExchangeFailed: "Échec de l'échange du token"
        case .refreshFailed: "Échec du rafraîchissement du token"
        case .emailFetchFailed: "Impossible de récupérer l'email"
        case .oauthTimeout: "La connexion a expiré (120s)"
        }
    }
}

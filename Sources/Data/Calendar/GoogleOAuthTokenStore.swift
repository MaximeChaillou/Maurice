import Foundation

struct GoogleTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum GoogleOAuthTokenStore {
    private static let service = "com.maxime.maurice.google-calendar"
    private static let account = "oauth-tokens"

    static func save(_ tokens: GoogleTokens) {
        let data: Data
        do {
            data = try JSONEncoder().encode(tokens)
        } catch {
            IssueLogger.log(.error, "Failed to encode Google tokens", error: error)
            return
        }
        do {
            try KeychainHelper.save(data: data, service: service, account: account)
        } catch {
            IssueLogger.log(.error, "Failed to save Google tokens to Keychain", error: error)
        }
    }

    static func load() -> GoogleTokens? {
        guard let data = KeychainHelper.load(service: service, account: account) else { return nil }
        do {
            return try JSONDecoder().decode(GoogleTokens.self, from: data)
        } catch {
            IssueLogger.log(.error, "Failed to decode Google OAuth tokens from Keychain", error: error)
            return nil
        }
    }

    static func clear() {
        KeychainHelper.delete(service: service, account: account)
    }
}

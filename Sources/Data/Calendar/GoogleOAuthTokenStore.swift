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
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        try? KeychainHelper.save(data: data, service: service, account: account)
    }

    static func load() -> GoogleTokens? {
        guard let data = KeychainHelper.load(service: service, account: account) else { return nil }
        return try? JSONDecoder().decode(GoogleTokens.self, from: data)
    }

    static func clear() {
        KeychainHelper.delete(service: service, account: account)
    }
}

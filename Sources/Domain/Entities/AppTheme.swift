import Foundation

struct AppTheme: PersistentCodable, Equatable {
    var markdown: MarkdownTheme = MarkdownTheme()

    var memoryTabHue: Double = 0.85

    // MARK: - Codable

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = AppTheme()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        markdown = try c.valueOrDefault(forKey: .markdown, default: defaults.markdown)
    }

    // MARK: - Persistence

    static var persistenceURL: URL {
        AppSettings.themeFileURL
    }
}

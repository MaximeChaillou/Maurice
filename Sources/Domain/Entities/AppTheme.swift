import Foundation

struct AppTheme: PersistentCodable, Equatable {
    var markdown: MarkdownTheme = MarkdownTheme()

    // MARK: - Tab background colors (stored as hue, 0...1)

    var meetingTabHue: Double = 0.60
    var peopleTabHue: Double = 0.75
    var taskTabHue: Double = 0.35
    var searchTabHue: Double = 0.52

    func hue(for tab: AppTab) -> Double {
        switch tab {
        case .meeting: meetingTabHue
        case .people: peopleTabHue
        case .task: taskTabHue
        case .search: searchTabHue
        }
    }

    mutating func setHue(_ hue: Double, for tab: AppTab) {
        switch tab {
        case .meeting: meetingTabHue = hue
        case .people: peopleTabHue = hue
        case .task: taskTabHue = hue
        case .search: searchTabHue = hue
        }
    }

    // MARK: - Codable

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = AppTheme()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        markdown = try c.decodeIfPresent(MarkdownTheme.self, forKey: .markdown) ?? defaults.markdown
        meetingTabHue = try c.decodeIfPresent(Double.self, forKey: .meetingTabHue) ?? defaults.meetingTabHue
        peopleTabHue = try c.decodeIfPresent(Double.self, forKey: .peopleTabHue) ?? defaults.peopleTabHue
        taskTabHue = try c.decodeIfPresent(Double.self, forKey: .taskTabHue) ?? defaults.taskTabHue
        searchTabHue = try c.decodeIfPresent(Double.self, forKey: .searchTabHue) ?? defaults.searchTabHue
    }

    // MARK: - Persistence

    static var persistenceURL: URL {
        AppSettings.themeFileURL
    }
}

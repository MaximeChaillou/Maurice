import Foundation

struct AppTheme: PersistentCodable, Equatable {
    var markdown: MarkdownTheme = MarkdownTheme()

    // MARK: - Tab background colors (stored as hue, 0...1)

    var meetingTabHue: Double = 0.5718
    var peopleTabHue: Double = 0.4604
    var taskTabHue: Double = 0.7501
    var memoryTabHue: Double = 0.85

    func hue(for tab: AppTab) -> Double {
        switch tab {
        case .meeting: meetingTabHue
        case .people: peopleTabHue
        case .task: taskTabHue
        }
    }

    mutating func setHue(_ hue: Double, for tab: AppTab) {
        switch tab {
        case .meeting: meetingTabHue = hue
        case .people: peopleTabHue = hue
        case .task: taskTabHue = hue
        }
    }

    // MARK: - Codable

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = AppTheme()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        markdown = try c.valueOrDefault(forKey: .markdown, default: defaults.markdown)
        meetingTabHue = try c.valueOrDefault(forKey: .meetingTabHue, default: defaults.meetingTabHue)
        peopleTabHue = try c.valueOrDefault(forKey: .peopleTabHue, default: defaults.peopleTabHue)
        taskTabHue = try c.valueOrDefault(forKey: .taskTabHue, default: defaults.taskTabHue)
    }

    // MARK: - Persistence

    static var persistenceURL: URL {
        AppSettings.themeFileURL
    }
}

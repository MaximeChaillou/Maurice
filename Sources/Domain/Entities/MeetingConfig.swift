import Foundation

struct MeetingConfig: Codable {
    var icon: String?
    var calendarEventName: String?
    var actions: [SkillAction]

    init(icon: String? = nil, calendarEventName: String? = nil, actions: [SkillAction] = []) {
        self.icon = icon
        self.calendarEventName = calendarEventName
        self.actions = actions
    }

    // MARK: - Persistence (per-folder)

    private static let fileName = ".config.json"

    static func load(from folderURL: URL) -> MeetingConfig {
        let url = folderURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return MeetingConfig() }
        return (try? JSONDecoder().decode(MeetingConfig.self, from: data)) ?? MeetingConfig()
    }

    static func loadAsync(from folderURL: URL) async -> MeetingConfig {
        await Task.detached { load(from: folderURL) }.value
    }

    func save(to folderURL: URL) {
        let url = folderURL.appendingPathComponent(Self.fileName)
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func saveAsync(to folderURL: URL) {
        let copy = self
        Task.detached {
            let url = folderURL.appendingPathComponent(Self.fileName)
            guard let data = try? JSONEncoder().encode(copy) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Actions

    mutating func addAction(_ action: SkillAction) {
        actions.append(action)
    }

    mutating func removeAction(id: UUID) {
        actions.removeAll { $0.id == id }
    }

    mutating func updateAction(id: UUID, buttonName: String, skillFilename: String, parameter: String? = nil) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index] = SkillAction(id: id, buttonName: buttonName, skillFilename: skillFilename, parameter: parameter)
    }
}

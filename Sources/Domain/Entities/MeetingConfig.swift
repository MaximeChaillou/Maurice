import Foundation

struct MeetingConfig: FolderPersistentCodable {
    var icon: String?
    var calendarEventName: String?
    var actions: [SkillAction]

    static let fileName = ".config.json"

    init(icon: String? = nil, calendarEventName: String? = nil, actions: [SkillAction] = []) {
        self.icon = icon
        self.calendarEventName = calendarEventName
        self.actions = actions
    }

    static let defaultActions: [SkillAction] = [
        SkillAction(buttonName: String(localized: "Prepare"), skillFilename: "prepare-meeting.md"),
        SkillAction(buttonName: String(localized: "Summarize"), skillFilename: "summarize-meeting.md"),
    ]

    init() {
        self.init(icon: nil, calendarEventName: nil, actions: Self.defaultActions)
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

import Foundation

struct SkillFile: Identifiable, Hashable, Codable {
    let filename: String

    var id: String { filename }

    var name: String {
        filename
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var url: URL {
        AppSettings.claudeCommandsDirectory.appendingPathComponent(filename)
    }

    var description: String {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return content.components(separatedBy: .newlines).first ?? ""
    }
}

struct SkillAction: Identifiable, Codable, Hashable {
    var id: UUID
    var buttonName: String
    var skillFilename: String

    init(id: UUID = UUID(), buttonName: String, skillFilename: String) {
        self.id = id
        self.buttonName = buttonName
        self.skillFilename = skillFilename
    }
}

struct MeetingSkillConfig: PersistentCodable {
    var folderActions: [String: [SkillAction]]

    init() {
        self.folderActions = [:]
    }

    init(folderActions: [String: [SkillAction]]) {
        self.folderActions = folderActions
    }

    func actions(for folderName: String) -> [SkillAction] {
        folderActions[folderName] ?? []
    }

    mutating func addAction(_ action: SkillAction, to folderName: String) {
        var current = folderActions[folderName] ?? []
        current.append(action)
        folderActions[folderName] = current
    }

    mutating func removeAction(id: UUID, from folderName: String) {
        var current = folderActions[folderName] ?? []
        current.removeAll { $0.id == id }
        folderActions[folderName] = current
    }

    mutating func updateAction(id: UUID, buttonName: String, skillFilename: String, in folderName: String) {
        guard var current = folderActions[folderName],
              let index = current.firstIndex(where: { $0.id == id })
        else { return }
        current[index] = SkillAction(id: id, buttonName: buttonName, skillFilename: skillFilename)
        folderActions[folderName] = current
    }

    // MARK: - Persistence

    static var persistenceURL: URL {
        AppSettings.rootDirectory.appendingPathComponent("meeting-skills.json")
    }

    // MARK: - Available skills

    static func availableSkills() -> [SkillFile] {
        let dir = AppSettings.claudeCommandsDirectory
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return [] }

        return items
            .filter { $0.pathExtension == "md" }
            .map { SkillFile(filename: $0.lastPathComponent) }
            .sorted { $0.name < $1.name }
    }
}

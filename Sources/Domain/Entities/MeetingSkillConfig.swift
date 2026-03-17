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
    var parameter: String?

    init(id: UUID = UUID(), buttonName: String, skillFilename: String, parameter: String? = nil) {
        self.id = id
        self.buttonName = buttonName
        self.skillFilename = skillFilename
        self.parameter = parameter
    }
}

enum MeetingSkillConfig {
    static func availableSkills() -> [SkillFile] {
        let dir = AppSettings.claudeCommandsDirectory
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return [] }

        return items
            .filter { $0.pathExtension == "md" && !$0.lastPathComponent.hasPrefix("maurice-") }
            .map { SkillFile(filename: $0.lastPathComponent) }
            .sorted { $0.name < $1.name }
    }

    static func availableSkillsAsync() async -> [SkillFile] {
        await Task.detached { availableSkills() }.value
    }
}

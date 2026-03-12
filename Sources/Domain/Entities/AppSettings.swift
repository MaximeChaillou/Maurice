import Foundation

enum AppSettings {
    private static let rootDirectoryKey = "rootDirectory"

    static var rootDirectory: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: rootDirectoryKey) {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            return defaultRootDirectory
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: rootDirectoryKey)
        }
    }

    static let defaultRootDirectory: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Maurice", isDirectory: true)
    }()

    static var transcriptsDirectory: URL {
        rootDirectory.appendingPathComponent("Transcripts", isDirectory: true)
    }

    static var memoryDirectory: URL {
        rootDirectory.appendingPathComponent("Memory", isDirectory: true)
    }

    static var meetingsDirectory: URL {
        rootDirectory.appendingPathComponent("Meetings", isDirectory: true)
    }

    static var peopleDirectory: URL {
        rootDirectory.appendingPathComponent("People", isDirectory: true)
    }

    static var tasksFileURL: URL {
        rootDirectory.appendingPathComponent("tasks.md")
    }

    static var claudeCommandsDirectory: URL {
        rootDirectory.appendingPathComponent(".claude/commands", isDirectory: true)
    }

    static var themeFileURL: URL {
        let dir = rootDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("theme.json")
    }
}

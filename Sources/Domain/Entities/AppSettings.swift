import Foundation

enum AppSettings {
    private static let rootDirectoryKey = "rootDirectory"
    private static let onboardingCompletedKey = "onboardingCompleted"
    private static let transcriptionLanguageKey = "transcriptionLanguage"
    private static let appLanguageKey = "appLanguage"

    static var appLanguage: String {
        get { UserDefaults.standard.string(forKey: appLanguageKey) ?? "system" }
        set {
            UserDefaults.standard.set(newValue, forKey: appLanguageKey)
            applyLanguage()
        }
    }

    static func applyLanguage() {
        let lang = appLanguage
        if lang == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        }
    }

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

    static var onboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingCompletedKey) }
    }

    static var transcriptionLanguage: String {
        get { UserDefaults.standard.string(forKey: transcriptionLanguageKey) ?? "fr-FR" }
        set { UserDefaults.standard.set(newValue, forKey: transcriptionLanguageKey) }
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
        rootDirectory.appendingPathComponent("Tasks.md")
    }

    static var claudeCommandsDirectory: URL {
        rootDirectory.appendingPathComponent(".claude/commands", isDirectory: true)
    }

    static var claudeMDURL: URL {
        rootDirectory.appendingPathComponent("CLAUDE.md")
    }

    private static var mauriceConfigDirectory: URL {
        rootDirectory.appendingPathComponent(".maurice", isDirectory: true)
    }

    static var themeFileURL: URL {
        let dir = mauriceConfigDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            IssueLogger.log(.error, "Failed to create .maurice config directory", context: dir.path, error: error)
        }
        return dir.appendingPathComponent("theme.json")
    }

    static var searchIndexURL: URL {
        mauriceConfigDirectory.appendingPathComponent("search_index.json")
    }
}

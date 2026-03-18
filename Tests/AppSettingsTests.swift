import XCTest
@testable import Maurice

final class AppSettingsTests: XCTestCase {

    // Save and restore UserDefaults values to avoid polluting test environment
    private var savedRootDirectory: String?
    private var savedLanguage: String?
    private var savedOnboarding: Bool = false

    override func setUp() {
        super.setUp()
        savedRootDirectory = UserDefaults.standard.string(forKey: "rootDirectory")
        savedLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage")
        savedOnboarding = UserDefaults.standard.bool(forKey: "onboardingCompleted")

        // Clear for clean tests
        UserDefaults.standard.removeObject(forKey: "rootDirectory")
        UserDefaults.standard.removeObject(forKey: "transcriptionLanguage")
        UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
    }

    override func tearDown() {
        // Restore original values
        if let root = savedRootDirectory {
            UserDefaults.standard.set(root, forKey: "rootDirectory")
        } else {
            UserDefaults.standard.removeObject(forKey: "rootDirectory")
        }
        if let lang = savedLanguage {
            UserDefaults.standard.set(lang, forKey: "transcriptionLanguage")
        } else {
            UserDefaults.standard.removeObject(forKey: "transcriptionLanguage")
        }
        UserDefaults.standard.set(savedOnboarding, forKey: "onboardingCompleted")
        super.tearDown()
    }

    // MARK: - Default root directory

    func testDefaultRootDirectoryIsInDocumentsMaurice() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let expected = documents.appendingPathComponent("Maurice", isDirectory: true)
        XCTAssertEqual(AppSettings.defaultRootDirectory, expected)
    }

    func testRootDirectoryFallsBackToDefault() {
        // rootDirectory key is cleared in setUp
        XCTAssertEqual(AppSettings.rootDirectory, AppSettings.defaultRootDirectory)
    }

    func testRootDirectoryGetSet() {
        let custom = URL(fileURLWithPath: "/tmp/TestMaurice", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.rootDirectory.path, custom.path)
    }

    // MARK: - Derived paths

    func testMemoryDirectoryDerivedFromRoot() {
        let custom = URL(fileURLWithPath: "/tmp/TestRoot", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.memoryDirectory.path, "/tmp/TestRoot/Memory")
    }

    func testMeetingsDirectoryDerivedFromRoot() {
        let custom = URL(fileURLWithPath: "/tmp/TestRoot", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.meetingsDirectory.path, "/tmp/TestRoot/Meetings")
    }

    func testPeopleDirectoryDerivedFromRoot() {
        let custom = URL(fileURLWithPath: "/tmp/TestRoot", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.peopleDirectory.path, "/tmp/TestRoot/People")
    }

    func testTasksFileURLDerivedFromRoot() {
        let custom = URL(fileURLWithPath: "/tmp/TestRoot", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.tasksFileURL.path, "/tmp/TestRoot/Tasks.md")
    }

    func testClaudeCommandsDirectoryDerivedFromRoot() {
        let custom = URL(fileURLWithPath: "/tmp/TestRoot", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.claudeCommandsDirectory.path, "/tmp/TestRoot/.claude/commands")
    }

    func testClaudeMDURLDerivedFromRoot() {
        let custom = URL(fileURLWithPath: "/tmp/TestRoot", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.claudeMDURL.path, "/tmp/TestRoot/CLAUDE.md")
    }

    func testSearchIndexURLDerivedFromRoot() {
        let custom = URL(fileURLWithPath: "/tmp/TestRoot", isDirectory: true)
        AppSettings.rootDirectory = custom
        XCTAssertEqual(AppSettings.searchIndexURL.path, "/tmp/TestRoot/.maurice/search_index.json")
    }

    func testThemeFileURLDerivedFromRoot() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppSettingsTest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        AppSettings.rootDirectory = tempDir
        let themeURL = AppSettings.themeFileURL
        XCTAssertEqual(themeURL.lastPathComponent, "theme.json")
        XCTAssertTrue(themeURL.path.contains(".maurice"))
    }

    func testDerivedPathsUpdateWhenRootChanges() {
        let first = URL(fileURLWithPath: "/tmp/First", isDirectory: true)
        AppSettings.rootDirectory = first
        XCTAssertEqual(AppSettings.memoryDirectory.path, "/tmp/First/Memory")

        let second = URL(fileURLWithPath: "/tmp/Second", isDirectory: true)
        AppSettings.rootDirectory = second
        XCTAssertEqual(AppSettings.memoryDirectory.path, "/tmp/Second/Memory")
    }

    // MARK: - transcriptionLanguage

    func testTranscriptionLanguageDefaultIsFrFR() {
        XCTAssertEqual(AppSettings.transcriptionLanguage, "fr-FR")
    }

    func testTranscriptionLanguageGetSet() {
        AppSettings.transcriptionLanguage = "en-US"
        XCTAssertEqual(AppSettings.transcriptionLanguage, "en-US")
    }

    func testTranscriptionLanguageRoundTrips() {
        let languages = ["fr-FR", "en-US", "de-DE", "ja-JP"]
        for lang in languages {
            AppSettings.transcriptionLanguage = lang
            XCTAssertEqual(AppSettings.transcriptionLanguage, lang)
        }
    }

    // MARK: - onboardingCompleted

    func testOnboardingCompletedDefaultIsFalse() {
        XCTAssertFalse(AppSettings.onboardingCompleted)
    }

    func testOnboardingCompletedGetSet() {
        AppSettings.onboardingCompleted = true
        XCTAssertTrue(AppSettings.onboardingCompleted)
    }

    func testOnboardingCompletedCanBeReset() {
        AppSettings.onboardingCompleted = true
        XCTAssertTrue(AppSettings.onboardingCompleted)
        AppSettings.onboardingCompleted = false
        XCTAssertFalse(AppSettings.onboardingCompleted)
    }
}

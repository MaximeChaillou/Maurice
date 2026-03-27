import XCTest
@testable import Maurice

final class FolderPersistentCodableTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FolderPersistentTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - MeetingConfig (implements FolderPersistentCodable)

    func testSaveAndLoadFromFolder() {
        var config = MeetingConfig()
        config.icon = "🎯"
        config.calendarEventName = "Test Meeting"
        config.save(to: tempDir)

        let loaded = MeetingConfig.load(from: tempDir)
        XCTAssertEqual(loaded.icon, "🎯")
        XCTAssertEqual(loaded.calendarEventName, "Test Meeting")
    }

    func testLoadFromEmptyFolderReturnsDefault() {
        let loaded = MeetingConfig.load(from: tempDir)
        XCTAssertNil(loaded.icon)
        XCTAssertNil(loaded.calendarEventName)
    }

    func testSaveOverwritesPrevious() {
        var config1 = MeetingConfig()
        config1.icon = "🔴"
        config1.save(to: tempDir)

        var config2 = MeetingConfig()
        config2.icon = "🟢"
        config2.save(to: tempDir)

        let loaded = MeetingConfig.load(from: tempDir)
        XCTAssertEqual(loaded.icon, "🟢")
    }

    func testSaveCreatesConfigFile() {
        let config = MeetingConfig()
        config.save(to: tempDir)

        let configFile = tempDir.appendingPathComponent(".config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configFile.path))
    }

    func testLoadWithCorruptedJSON() throws {
        let configFile = tempDir.appendingPathComponent(".config.json")
        try "not valid json {{{".write(to: configFile, atomically: true, encoding: .utf8)

        let loaded = MeetingConfig.load(from: tempDir)
        // Should return default instance on corruption (which includes defaultActions)
        XCTAssertNil(loaded.icon)
        XCTAssertEqual(loaded.actions.count, MeetingConfig.defaultActions.count)
    }

    func testSaveAndLoadWithActions() {
        var config = MeetingConfig(icon: nil, calendarEventName: nil, actions: [])
        config.addAction(SkillAction(buttonName: "Resume", skillFilename: "resume.md"))
        config.save(to: tempDir)

        let loaded = MeetingConfig.load(from: tempDir)
        XCTAssertEqual(loaded.actions.count, 1)
        XCTAssertEqual(loaded.actions[0].buttonName, "Resume")
        XCTAssertEqual(loaded.actions[0].skillFilename, "resume.md")
    }

    func testAsyncLoadFromFolder() async {
        var config = MeetingConfig()
        config.icon = "⚡"
        config.save(to: tempDir)

        let loaded = await MeetingConfig.loadAsync(from: tempDir)
        XCTAssertEqual(loaded.icon, "⚡")
    }
}

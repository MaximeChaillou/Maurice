import XCTest
@testable import Maurice

final class PersistentCodableTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - FolderPersistentCodable: load from folder

    func testLoadFromFolderWhenFileExists() {
        let config = MeetingConfig(icon: "star", calendarEventName: "Standup", actions: [])
        config.save(to: tempDir)

        let loaded = MeetingConfig.load(from: tempDir)

        XCTAssertEqual(loaded.icon, "star")
        XCTAssertEqual(loaded.calendarEventName, "Standup")
        XCTAssertTrue(loaded.actions.isEmpty)
    }

    func testLoadFromFolderWhenFileMissing() {
        let loaded = MeetingConfig.load(from: tempDir)

        XCTAssertNil(loaded.icon)
        XCTAssertNil(loaded.calendarEventName)
        XCTAssertEqual(loaded.actions.count, MeetingConfig.defaultActions.count)
    }

    func testLoadFromFolderWhenFileIsCorrupt() {
        let fileURL = tempDir.appendingPathComponent(MeetingConfig.fileName)
        let garbage = "not valid json {{{".data(using: .utf8)!
        try? garbage.write(to: fileURL, options: .atomic)

        let loaded = MeetingConfig.load(from: tempDir)

        XCTAssertNil(loaded.icon)
        XCTAssertNil(loaded.calendarEventName)
        XCTAssertEqual(loaded.actions.count, MeetingConfig.defaultActions.count)
    }

    func testLoadFromFolderWhenFileIsEmptyJSON() throws {
        let fileURL = tempDir.appendingPathComponent(MeetingConfig.fileName)
        let emptyJSON = "{}".data(using: .utf8)!
        try emptyJSON.write(to: fileURL, options: .atomic)

        let loaded = MeetingConfig.load(from: tempDir)

        // Empty JSON should decode with default values from Codable
        XCTAssertNil(loaded.icon)
        XCTAssertNil(loaded.calendarEventName)
    }

    // MARK: - FolderPersistentCodable: save to folder

    func testSaveToFolderCreatesFile() {
        let config = MeetingConfig(icon: "rocket", calendarEventName: "Review", actions: [])
        config.save(to: tempDir)

        let fileURL = tempDir.appendingPathComponent(MeetingConfig.fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSaveToFolderWritesValidJSON() throws {
        let action = SkillAction(buttonName: "Test", skillFilename: "test.md")
        let config = MeetingConfig(icon: "heart", calendarEventName: "Daily", actions: [action])
        config.save(to: tempDir)

        let fileURL = tempDir.appendingPathComponent(MeetingConfig.fileName)
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode(MeetingConfig.self, from: data)

        XCTAssertEqual(decoded.icon, "heart")
        XCTAssertEqual(decoded.calendarEventName, "Daily")
        XCTAssertEqual(decoded.actions.count, 1)
        XCTAssertEqual(decoded.actions.first?.buttonName, "Test")
    }

    func testSaveOverwritesPreviousFile() {
        let config1 = MeetingConfig(icon: "first", actions: [])
        config1.save(to: tempDir)

        let config2 = MeetingConfig(icon: "second", actions: [])
        config2.save(to: tempDir)

        let loaded = MeetingConfig.load(from: tempDir)
        XCTAssertEqual(loaded.icon, "second")
    }

    // MARK: - FolderPersistentCodable: loadAsync

    func testLoadAsyncFromFolderWhenFileExists() async {
        let config = MeetingConfig(icon: "async-icon", calendarEventName: "Async Meeting", actions: [])
        config.save(to: tempDir)

        let loaded = await MeetingConfig.loadAsync(from: tempDir)

        XCTAssertEqual(loaded.icon, "async-icon")
        XCTAssertEqual(loaded.calendarEventName, "Async Meeting")
    }

    func testLoadAsyncFromFolderWhenFileMissing() async {
        let loaded = await MeetingConfig.loadAsync(from: tempDir)

        XCTAssertNil(loaded.icon)
        XCTAssertEqual(loaded.actions.count, MeetingConfig.defaultActions.count)
    }

    func testLoadAsyncFromFolderWhenFileIsCorrupt() async {
        let fileURL = tempDir.appendingPathComponent(MeetingConfig.fileName)
        let garbage = "<<<invalid>>>".data(using: .utf8)!
        try? garbage.write(to: fileURL, options: .atomic)

        let loaded = await MeetingConfig.loadAsync(from: tempDir)

        XCTAssertNil(loaded.icon)
        XCTAssertEqual(loaded.actions.count, MeetingConfig.defaultActions.count)
    }

    // MARK: - FolderPersistentCodable: saveAsync

    func testSaveAsyncWritesFile() async throws {
        let config = MeetingConfig(icon: "async-save", actions: [])
        config.saveAsync(to: tempDir)

        // Wait for async write to complete
        try await Task.sleep(for: .milliseconds(500))

        let loaded = MeetingConfig.load(from: tempDir)
        XCTAssertEqual(loaded.icon, "async-save")
    }

    // MARK: - FolderPersistentCodable: fileName

    func testMeetingConfigFileName() {
        XCTAssertEqual(MeetingConfig.fileName, ".config.json")
    }

    // MARK: - Roundtrip save then load

    func testRoundtripSaveThenLoad() {
        let action = SkillAction(buttonName: "Summarize", skillFilename: "summarize.md", parameter: "brief")
        let original = MeetingConfig(icon: "brain", calendarEventName: "Planning", actions: [action])

        original.save(to: tempDir)
        let loaded = MeetingConfig.load(from: tempDir)

        XCTAssertEqual(loaded.icon, original.icon)
        XCTAssertEqual(loaded.calendarEventName, original.calendarEventName)
        XCTAssertEqual(loaded.actions.count, original.actions.count)
        XCTAssertEqual(loaded.actions.first?.buttonName, original.actions.first?.buttonName)
        XCTAssertEqual(loaded.actions.first?.skillFilename, original.actions.first?.skillFilename)
        XCTAssertEqual(loaded.actions.first?.parameter, original.actions.first?.parameter)
    }
}

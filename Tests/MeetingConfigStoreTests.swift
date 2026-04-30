import XCTest
@testable import Maurice

final class MeetingConfigStoreTests: XCTestCase {

    private var tempRoot: URL!
    private var originalRootDirectory: String?

    override func setUp() async throws {
        try await super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetingConfigStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        originalRootDirectory = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempRoot.path, forKey: "rootDirectory")
        MeetingConfigStore.shared.reset()
    }

    override func tearDown() async throws {
        MeetingConfigStore.shared.reset()
        if let original = originalRootDirectory {
            UserDefaults.standard.set(original, forKey: "rootDirectory")
        } else {
            UserDefaults.standard.removeObject(forKey: "rootDirectory")
        }
        try? FileManager.default.removeItem(at: tempRoot)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeFolder(_ relativePath: String) -> URL {
        let url = tempRoot.appendingPathComponent(relativePath, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeLegacyConfig(_ config: MeetingConfig, in folderURL: URL) throws {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let url = folderURL.appendingPathComponent(".config.json")
        let data = try JSONEncoder().encode(config)
        try data.write(to: url, options: .atomic)
    }

    private func waitForPersist() async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    // MARK: - Bootstrap & basic access

    func testBootstrapWithoutFileReturnsDefaults() async {
        await MeetingConfigStore.shared.bootstrap()
        let folder = makeFolder("Meetings/Standup")

        let config = MeetingConfigStore.shared.config(for: folder)

        XCTAssertNil(config.icon)
        XCTAssertNil(config.calendarEventName)
        XCTAssertEqual(config.actions.count, MeetingConfig.defaultActions.count)
    }

    func testUpdateAndReadBack() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let folder = makeFolder("Meetings/Standup")
        let config = MeetingConfig(icon: "🚀", calendarEventName: "Daily", actions: [])

        MeetingConfigStore.shared.update(config, for: folder)
        try await waitForPersist()

        let loaded = MeetingConfigStore.shared.config(for: folder)
        XCTAssertEqual(loaded.icon, "🚀")
        XCTAssertEqual(loaded.calendarEventName, "Daily")
    }

    func testUpdatePersistsToDisk() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let folder = makeFolder("Meetings/Standup")
        let config = MeetingConfig(icon: "🚀", calendarEventName: "Daily", actions: [])

        MeetingConfigStore.shared.update(config, for: folder)
        try await waitForPersist()

        let fileURL = AppSettings.meetingConfigsURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([String: MeetingConfig].self, from: data)
        XCTAssertEqual(decoded["Meetings/Standup"]?.icon, "🚀")
    }

    func testRebootstrapAfterResetReadsFromDisk() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let folder = makeFolder("Meetings/Standup")
        MeetingConfigStore.shared.update(
            MeetingConfig(icon: "💡", calendarEventName: nil, actions: []),
            for: folder
        )
        try await waitForPersist()

        MeetingConfigStore.shared.reset()
        await MeetingConfigStore.shared.bootstrap()

        let loaded = MeetingConfigStore.shared.config(for: folder)
        XCTAssertEqual(loaded.icon, "💡")
    }

    // MARK: - Remove / move

    func testRemoveDropsConfigAndDescendants() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let person = makeFolder("People/Team/Alice")
        let oneOnOne = makeFolder("People/Team/Alice/1-1")
        MeetingConfigStore.shared.update(MeetingConfig(icon: "👤", actions: []), for: person)
        MeetingConfigStore.shared.update(MeetingConfig(calendarEventName: "1-1 Alice", actions: []), for: oneOnOne)
        try await waitForPersist()

        MeetingConfigStore.shared.remove(for: person)
        try await waitForPersist()

        XCTAssertNil(MeetingConfigStore.shared.config(for: person).icon)
        XCTAssertNil(MeetingConfigStore.shared.config(for: oneOnOne).calendarEventName)
    }

    func testMoveRekeysConfigAndDescendants() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let oldFolder = makeFolder("People/Team/Alice")
        let oldOneOnOne = makeFolder("People/Team/Alice/1-1")
        MeetingConfigStore.shared.update(MeetingConfig(icon: "👤", actions: []), for: oldFolder)
        MeetingConfigStore.shared.update(MeetingConfig(calendarEventName: "Alice 1-1", actions: []), for: oldOneOnOne)
        try await waitForPersist()

        let newFolder = tempRoot.appendingPathComponent("People/Team/Alicia", isDirectory: true)
        let newOneOnOne = newFolder.appendingPathComponent("1-1", isDirectory: true)
        MeetingConfigStore.shared.move(from: oldFolder, to: newFolder)
        try await waitForPersist()

        XCTAssertEqual(MeetingConfigStore.shared.config(for: newFolder).icon, "👤")
        XCTAssertEqual(MeetingConfigStore.shared.config(for: newOneOnOne).calendarEventName, "Alice 1-1")
        XCTAssertNil(MeetingConfigStore.shared.config(for: oldFolder).icon)
    }

    // MARK: - Migration

    func testMigrationConsolidatesLegacyConfigs() async throws {
        let standup = tempRoot.appendingPathComponent("Meetings/Standup", isDirectory: true)
        let oneOnOne = tempRoot.appendingPathComponent("People/Team/Alice/1-1", isDirectory: true)
        try writeLegacyConfig(MeetingConfig(icon: "🟢", calendarEventName: "Standup", actions: []), in: standup)
        try writeLegacyConfig(MeetingConfig(icon: nil, calendarEventName: "Alice", actions: []), in: oneOnOne)

        await MeetingConfigStore.shared.bootstrap()

        XCTAssertEqual(MeetingConfigStore.shared.config(for: standup).icon, "🟢")
        XCTAssertEqual(MeetingConfigStore.shared.config(for: oneOnOne).calendarEventName, "Alice")
    }

    func testMigrationDeletesLegacyFiles() async throws {
        let standup = tempRoot.appendingPathComponent("Meetings/Standup", isDirectory: true)
        try writeLegacyConfig(MeetingConfig(icon: "🟢", actions: []), in: standup)
        let legacyURL = standup.appendingPathComponent(".config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyURL.path))

        await MeetingConfigStore.shared.bootstrap()

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    func testMigrationSkipsWhenCentralFileExists() async throws {
        // Pre-populate the central file with empty configs
        let centralURL = AppSettings.meetingConfigsURL
        try FileManager.default.createDirectory(
            at: centralURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: centralURL, options: .atomic)

        // Drop a legacy file that should NOT be migrated
        let standup = tempRoot.appendingPathComponent("Meetings/Standup", isDirectory: true)
        try writeLegacyConfig(MeetingConfig(icon: "🟢", actions: []), in: standup)
        let legacyURL = standup.appendingPathComponent(".config.json")

        await MeetingConfigStore.shared.bootstrap()

        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyURL.path),
                      "Legacy file must be preserved when central file exists")
        XCTAssertNil(MeetingConfigStore.shared.config(for: standup).icon)
    }

    // MARK: - Notifications

    /// Awaits the next `meetingConfigDidChange` notification, returning its
    /// `userInfo`. Subscribes BEFORE the action so the post is not missed.
    private func captureNextChange(
        timeout: TimeInterval = 1.0,
        action: () -> Void
    ) async -> [AnyHashable: Any]? {
        let exp = expectation(description: "meetingConfigDidChange")
        nonisolated(unsafe) var captured: [AnyHashable: Any]?
        let token = NotificationCenter.default.addObserver(
            forName: .meetingConfigDidChange,
            object: nil,
            queue: .main
        ) { note in
            captured = note.userInfo ?? [:]
            exp.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }
        action()
        await fulfillment(of: [exp], timeout: timeout)
        return captured
    }

    func testUpdatePostsChangeNotificationWithFolderKey() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let folder = makeFolder("Meetings/Standup")

        let info = await captureNextChange {
            MeetingConfigStore.shared.update(MeetingConfig(icon: "🚀", actions: []), for: folder)
        }

        XCTAssertEqual(info?["folderKey"] as? String, "Meetings/Standup")
    }

    func testRemovePostsChangeNotificationWithFolderKey() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let folder = makeFolder("Meetings/Standup")
        MeetingConfigStore.shared.update(MeetingConfig(icon: "🚀", actions: []), for: folder)
        try await waitForPersist()

        let info = await captureNextChange {
            MeetingConfigStore.shared.remove(for: folder)
        }

        XCTAssertEqual(info?["folderKey"] as? String, "Meetings/Standup")
    }

    func testMovePostsChangeNotificationWithOldAndNewKeys() async throws {
        await MeetingConfigStore.shared.bootstrap()
        let oldFolder = makeFolder("People/Team/Alice")
        MeetingConfigStore.shared.update(MeetingConfig(icon: "👤", actions: []), for: oldFolder)
        try await waitForPersist()

        let newFolder = tempRoot.appendingPathComponent("People/Team/Alicia", isDirectory: true)
        let info = await captureNextChange {
            MeetingConfigStore.shared.move(from: oldFolder, to: newFolder)
        }

        XCTAssertEqual(info?["oldKey"] as? String, "People/Team/Alice")
        XCTAssertEqual(info?["newKey"] as? String, "People/Team/Alicia")
    }

    func testBootstrapPostsBulkReloadNotification() async throws {
        // Pre-populate disk so bootstrap loads from disk (replace path).
        let centralURL = AppSettings.meetingConfigsURL
        try FileManager.default.createDirectory(
            at: centralURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: centralURL, options: .atomic)
        MeetingConfigStore.shared.reset()

        let info = await captureNextChange {
            Task { await MeetingConfigStore.shared.bootstrap() }
        }

        // Bulk reload: empty userInfo (no folderKey).
        XCTAssertNil(info?["folderKey"])
        XCTAssertNil(info?["oldKey"])
        XCTAssertNil(info?["newKey"])
    }

    // MARK: - Notification.affectsMeetingConfig

    func testAffectsMeetingConfigMatchesUpdateKey() {
        let folder = tempRoot.appendingPathComponent("Meetings/Standup", isDirectory: true)
        let note = Notification(
            name: .meetingConfigDidChange,
            object: nil,
            userInfo: ["folderKey": "Meetings/Standup"]
        )
        XCTAssertTrue(note.affectsMeetingConfig(for: folder))
    }

    func testAffectsMeetingConfigMatchesMoveOldKey() {
        let folder = tempRoot.appendingPathComponent("People/Team/Alice", isDirectory: true)
        let note = Notification(
            name: .meetingConfigDidChange,
            object: nil,
            userInfo: ["oldKey": "People/Team/Alice", "newKey": "People/Team/Alicia"]
        )
        XCTAssertTrue(note.affectsMeetingConfig(for: folder))
    }

    func testAffectsMeetingConfigMatchesMoveNewKey() {
        let folder = tempRoot.appendingPathComponent("People/Team/Alicia", isDirectory: true)
        let note = Notification(
            name: .meetingConfigDidChange,
            object: nil,
            userInfo: ["oldKey": "People/Team/Alice", "newKey": "People/Team/Alicia"]
        )
        XCTAssertTrue(note.affectsMeetingConfig(for: folder))
    }

    func testAffectsMeetingConfigDoesNotMatchUnrelatedKey() {
        let folder = tempRoot.appendingPathComponent("Meetings/Other", isDirectory: true)
        let note = Notification(
            name: .meetingConfigDidChange,
            object: nil,
            userInfo: ["folderKey": "Meetings/Standup"]
        )
        XCTAssertFalse(note.affectsMeetingConfig(for: folder))
    }

    func testAffectsMeetingConfigMatchesBulkReloadWhenUserInfoEmpty() {
        let folder = tempRoot.appendingPathComponent("Meetings/Anything", isDirectory: true)
        let emptyInfo = Notification(name: .meetingConfigDidChange, object: nil, userInfo: [:])
        XCTAssertTrue(emptyInfo.affectsMeetingConfig(for: folder))

        let nilInfo = Notification(name: .meetingConfigDidChange, object: nil, userInfo: nil)
        XCTAssertTrue(nilInfo.affectsMeetingConfig(for: folder))
    }

    // MARK: - Key derivation

    func testRelativeKeyForRootSubfolder() {
        let folder = tempRoot.appendingPathComponent("Meetings/Standup", isDirectory: true)
        XCTAssertEqual(MeetingConfigStore.relativeKey(for: folder), "Meetings/Standup")
    }

    func testRelativeKeyForRootItself() {
        XCTAssertEqual(MeetingConfigStore.relativeKey(for: tempRoot), "")
    }

    func testRelativeKeyForUnrelatedURLReturnsAbsolutePath() {
        let unrelated = URL(fileURLWithPath: "/tmp/elsewhere", isDirectory: true)
        let key = MeetingConfigStore.relativeKey(for: unrelated)
        XCTAssertTrue(key.hasPrefix("/"))
    }
}

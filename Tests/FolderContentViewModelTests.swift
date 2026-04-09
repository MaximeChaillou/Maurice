import XCTest
@testable import Maurice

@MainActor
final class FolderContentViewModelTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try await super.tearDown()
    }

    private func createSubfolder(_ name: String) -> URL {
        let url = tempDir.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func createFile(_ name: String, in dir: URL) {
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: "content".data(using: .utf8))
    }

    // MARK: - Initial state

    func testInitialState() {
        let vm = FolderContentViewModel(directory: tempDir)
        XCTAssertTrue(vm.folders.isEmpty)
        XCTAssertNil(vm.selectedFolder)
        XCTAssertNil(vm.selectedFile)
        XCTAssertEqual(vm.fileIndex, 0)
        XCTAssertFalse(vm.isAddingFolder)
        XCTAssertEqual(vm.newFolderName, "")
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.currentFolder)
    }

    // MARK: - loadFolders

    func testLoadFoldersPopulatesList() async throws {
        let sub = createSubfolder("ProjectA")
        createFile("2024-01-01.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.folders.count, 1)
        XCTAssertEqual(vm.folders.first?.name, "ProjectA")
    }

    func testLoadFoldersSortsAlphabetically() async throws {
        _ = createSubfolder("Zebra")
        _ = createSubfolder("Apple")
        _ = createSubfolder("Mango")

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let names = vm.folders.map(\.name)
        XCTAssertEqual(names, ["Apple", "Mango", "Zebra"])
    }

    func testLoadFoldersScansFiles() async throws {
        let sub = createSubfolder("Folder")
        createFile("2024-01-15.md", in: sub)
        createFile("2024-02-20.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.folders.first?.files.count, 2)
    }

    // MARK: - createFolder

    func testCreateFolderFromNewFolderName() async throws {
        let vm = FolderContentViewModel(directory: tempDir)
        vm.newFolderName = "New Project"
        vm.isAddingFolder = true

        vm.createFolder()
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.newFolderName, "")
        XCTAssertFalse(vm.isAddingFolder)
        XCTAssertEqual(vm.selectedFolder, "New Project")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("New Project").path))
    }

    func testCreateFolderWithEmptyNameDoesNothing() async throws {
        let vm = FolderContentViewModel(directory: tempDir)
        vm.newFolderName = "   "
        vm.createFolder()
        try await Task.sleep(for: .milliseconds(300))

        // Directory should still be empty (no folders created)
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertTrue(contents.isEmpty)
    }

    func testCreateFolderWithName() async throws {
        let vm = FolderContentViewModel(directory: tempDir)
        let name = vm.createFolderWithName("TestFolder")

        XCTAssertEqual(name, "TestFolder")
        XCTAssertEqual(vm.selectedFolder, "TestFolder")

        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("TestFolder").path))
    }

    // MARK: - renameFolder

    func testRenameFolderSuccess() async throws {
        let sub = createSubfolder("OldName")
        createFile("note.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "OldName"
        let folder = vm.folders.first!
        let result = vm.renameFolder(folder, to: "NewName")

        XCTAssertTrue(result)
        XCTAssertEqual(vm.selectedFolder, "NewName")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("NewName").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("OldName").path))
    }

    func testRenameFolderWithEmptyNameReturnsFalse() async throws {
        let sub = createSubfolder("Folder")
        createFile("note.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first!
        let result = vm.renameFolder(folder, to: "  ")

        XCTAssertFalse(result)
    }

    func testRenameFolderWithSameNameReturnsFalse() async throws {
        let sub = createSubfolder("Same")
        createFile("note.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first!
        let result = vm.renameFolder(folder, to: "Same")

        XCTAssertFalse(result)
    }

    func testRenameFolderToExistingNameReturnsFalse() async throws {
        _ = createSubfolder("FolderA")
        _ = createSubfolder("FolderB")

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folderA = vm.folders.first { $0.name == "FolderA" }!
        let result = vm.renameFolder(folderA, to: "FolderB")

        XCTAssertFalse(result)
    }

    // MARK: - deleteFolder

    func testDeleteFolderRemovesFromDisk() async throws {
        let sub = createSubfolder("ToDelete")
        createFile("data.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "ToDelete"
        let folder = vm.folders.first!
        vm.deleteFolder(folder)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sub.path))
        XCTAssertNil(vm.selectedFolder)
    }

    func testDeleteFolderClearsSelectedIfMatch() async throws {
        _ = createSubfolder("Selected")

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "Selected"
        let folder = vm.folders.first!
        vm.deleteFolder(folder)

        XCTAssertNil(vm.selectedFolder)
    }

    func testDeleteFolderKeepsSelectedIfDifferent() async throws {
        _ = createSubfolder("Other")
        _ = createSubfolder("ToDelete")

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "Other"
        let folder = vm.folders.first { $0.name == "ToDelete" }!
        vm.deleteFolder(folder)

        XCTAssertEqual(vm.selectedFolder, "Other")
    }

    // MARK: - deleteDateEntry

    func testDeleteDateEntryRemovesNoteFile() async throws {
        let sub = createSubfolder("Meeting")
        createFile("2024-01-01.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let noteURL = sub.appendingPathComponent("2024-01-01.md")
        let noteFile = FolderFile(id: noteURL, name: "2024-01-01", date: Date(), url: noteURL)
        let entry = MeetingDateEntry(dateString: "2024-01-01", date: Date(), noteFile: noteFile, transcript: nil)

        vm.deleteDateEntry(entry)

        XCTAssertFalse(FileManager.default.fileExists(atPath: noteURL.path))
    }

    func testDeleteDateEntryNoteOnly() async throws {
        let sub = createSubfolder("Meeting")
        createFile("2024-01-01.md", in: sub)

        let noteURL = sub.appendingPathComponent("2024-01-01.md")
        let noteFile = FolderFile(id: noteURL, name: "2024-01-01", date: Date(), url: noteURL)
        let entry = MeetingDateEntry(dateString: "2024-01-01", date: Date(), noteFile: noteFile, transcript: nil)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.deleteDateEntry(entry, noteOnly: true)

        // noteOnly doesn't delete transcript (there isn't one anyway)
        // But it does delete the note
        XCTAssertFalse(FileManager.default.fileExists(atPath: noteURL.path))
    }

    func testDeleteDateEntryTranscriptOnly() async throws {
        let sub = createSubfolder("Meeting")
        createFile("2024-01-01.md", in: sub)

        let noteURL = sub.appendingPathComponent("2024-01-01.md")
        let noteFile = FolderFile(id: noteURL, name: "2024-01-01", date: Date(), url: noteURL)
        let entry = MeetingDateEntry(dateString: "2024-01-01", date: Date(), noteFile: noteFile, transcript: nil)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.deleteDateEntry(entry, transcriptOnly: true)

        // transcriptOnly should NOT delete the note
        XCTAssertTrue(FileManager.default.fileExists(atPath: noteURL.path))
    }

    // MARK: - updateCurrentFolderIcon

    func testUpdateCurrentFolderIcon() async throws {
        _ = createSubfolder("Folder")

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "Folder"
        XCTAssertNil(vm.currentFolder?.icon)

        vm.updateCurrentFolderIcon("star")

        XCTAssertEqual(vm.currentFolder?.icon, "star")
    }

    func testUpdateCurrentFolderIconWithNoSelectionDoesNothing() {
        let vm = FolderContentViewModel(directory: tempDir)
        vm.updateCurrentFolderIcon("star")
        // Should not crash, no folders to update
    }

    // MARK: - selectFileAtIndex

    func testSelectFileAtIndex() async throws {
        let sub = createSubfolder("Project")
        createFile("2024-01-01.md", in: sub)
        createFile("2024-02-01.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first!
        vm.fileIndex = 0
        vm.selectFileAtIndex(in: folder)

        XCTAssertNotNil(vm.selectedFile)
        // Files sorted descending, so first should be 2024-02-01
        XCTAssertTrue(vm.selectedFile?.lastPathComponent.contains("2024-02") ?? false)
    }

    func testSelectFileAtIndexClampsToLastFile() async throws {
        let sub = createSubfolder("Project")
        createFile("2024-01-01.md", in: sub)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first!
        vm.fileIndex = 999
        vm.selectFileAtIndex(in: folder)

        XCTAssertNotNil(vm.selectedFile)
    }

    func testSelectFileAtIndexWithEmptyFolderDoesNothing() {
        let folder = FolderItem(name: "Empty", url: tempDir, files: [])
        let vm = FolderContentViewModel(directory: tempDir)
        vm.selectFileAtIndex(in: folder)

        XCTAssertNil(vm.selectedFile)
    }

    // MARK: - currentFolder

    func testCurrentFolderReturnsMatchingFolder() async throws {
        _ = createSubfolder("Match")

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "Match"
        XCTAssertNotNil(vm.currentFolder)
        XCTAssertEqual(vm.currentFolder?.name, "Match")
    }

    func testCurrentFolderReturnsNilWhenNoMatch() async throws {
        _ = createSubfolder("Folder")

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "NonExistent"
        XCTAssertNil(vm.currentFolder)
    }

    func testCurrentFolderReturnsNilWhenNoSelection() {
        let vm = FolderContentViewModel(directory: tempDir)
        XCTAssertNil(vm.currentFolder)
    }

    // MARK: - meetingConfig

    func testMeetingConfigDefaultValues() {
        let vm = FolderContentViewModel(directory: tempDir)
        XCTAssertNil(vm.meetingConfig.icon)
        XCTAssertNil(vm.meetingConfig.calendarEventName)
        XCTAssertEqual(vm.meetingConfig.actions.count, MeetingConfig.defaultActions.count)
    }

    // MARK: - moveFolderContent

    func testMoveFolderContentMovesFiles() async throws {
        let source = createSubfolder("SourceMeeting")
        let dest = createSubfolder("DestMeeting")
        createFile("2024-01-01.md", in: source)
        createFile("2024-01-01.transcript", in: source)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first { $0.name == "SourceMeeting" }!
        vm.selectedFolder = "SourceMeeting"
        vm.moveFolderContent(folder, to: dest)
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("2024-01-01.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("2024-01-01.transcript").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("2024-01-01.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("2024-01-01.transcript").path))
        XCTAssertNil(vm.selectedFolder)
    }

    func testMoveFolderContentSkipsNextMd() async throws {
        let source = createSubfolder("SourceMeeting")
        let dest = createSubfolder("DestMeeting")
        createFile("next.md", in: source)
        createFile("2024-01-01.md", in: source)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first { $0.name == "SourceMeeting" }!
        vm.moveFolderContent(folder, to: dest)
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent("next.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.appendingPathComponent("next.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("2024-01-01.md").path))
    }

    func testMoveFolderContentSkipsNonMdNonTranscript() async throws {
        let source = createSubfolder("SourceMeeting")
        let dest = createSubfolder("DestMeeting")
        createFile("2024-01-01.md", in: source)
        createFile(".config.json", in: source)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first { $0.name == "SourceMeeting" }!
        vm.moveFolderContent(folder, to: dest)
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent(".config.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.appendingPathComponent(".config.json").path))
    }

    func testMoveFolderContentMergesWhenDestFileExists() async throws {
        let source = createSubfolder("SourceMeeting")
        let dest = createSubfolder("DestMeeting")

        let sourceFile = source.appendingPathComponent("2024-01-01.md")
        try "Source content".write(to: sourceFile, atomically: true, encoding: .utf8)
        let destFile = dest.appendingPathComponent("2024-01-01.md")
        try "Dest content".write(to: destFile, atomically: true, encoding: .utf8)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        let folder = vm.folders.first { $0.name == "SourceMeeting" }!
        vm.moveFolderContent(folder, to: dest)
        try await Task.sleep(for: .milliseconds(500))

        let merged = try String(contentsOf: destFile, encoding: .utf8)
        XCTAssertTrue(merged.contains("Dest content"))
        XCTAssertTrue(merged.contains("Source content"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
    }

    func testMoveFolderContentClearsSelection() async throws {
        let source = createSubfolder("SourceMeeting")
        _ = createSubfolder("DestMeeting")
        createFile("2024-01-01.md", in: source)

        let vm = FolderContentViewModel(directory: tempDir)
        vm.loadFolders()
        try await Task.sleep(for: .milliseconds(500))

        vm.selectedFolder = "SourceMeeting"
        let folder = vm.folders.first { $0.name == "SourceMeeting" }!
        vm.moveFolderContent(folder, to: tempDir.appendingPathComponent("DestMeeting"))
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertNil(vm.selectedFolder)
    }

    // MARK: - listMoveDestinations

    func testListMoveDestinationsExcludesCurrentFolder() async throws {
        _ = createSubfolder("Meeting1")
        _ = createSubfolder("Meeting2")
        _ = createSubfolder("Meeting3")

        let originalRoot = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempDir.path, forKey: "rootDirectory")
        defer {
            if let original = originalRoot {
                UserDefaults.standard.set(original, forKey: "rootDirectory")
            } else {
                UserDefaults.standard.removeObject(forKey: "rootDirectory")
            }
        }

        // Create Meetings directory and move subfolders there
        let meetingsDir = tempDir.appendingPathComponent("Meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)
        try FileManager.default.moveItem(
            at: tempDir.appendingPathComponent("Meeting1"),
            to: meetingsDir.appendingPathComponent("Meeting1")
        )
        try FileManager.default.moveItem(
            at: tempDir.appendingPathComponent("Meeting2"),
            to: meetingsDir.appendingPathComponent("Meeting2")
        )
        try FileManager.default.moveItem(
            at: tempDir.appendingPathComponent("Meeting3"),
            to: meetingsDir.appendingPathComponent("Meeting3")
        )

        let folder = FolderItem(
            name: "Meeting1",
            url: meetingsDir.appendingPathComponent("Meeting1"),
            files: []
        )

        let destinations = FolderContentViewModel.listMoveDestinations(excluding: folder)
        let meetingNames = destinations.filter { $0.section == "Meetings" }.map(\.name)

        XCTAssertFalse(meetingNames.contains("Meeting1"))
        XCTAssertTrue(meetingNames.contains("Meeting2"))
        XCTAssertTrue(meetingNames.contains("Meeting3"))
    }

    func testListMoveDestinationsIncludesPeopleOneOnOne() async throws {
        let originalRoot = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempDir.path, forKey: "rootDirectory")
        defer {
            if let original = originalRoot {
                UserDefaults.standard.set(original, forKey: "rootDirectory")
            } else {
                UserDefaults.standard.removeObject(forKey: "rootDirectory")
            }
        }

        // Create People structure
        let meetingsDir = tempDir.appendingPathComponent("Meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)
        let meetingDir = meetingsDir.appendingPathComponent("Standup", isDirectory: true)
        try FileManager.default.createDirectory(at: meetingDir, withIntermediateDirectories: true)

        let peopleDir = tempDir.appendingPathComponent("People", isDirectory: true)
        let personDir = peopleDir
            .appendingPathComponent("Engineering", isDirectory: true)
            .appendingPathComponent("John", isDirectory: true)
        let oneOnOneDir = personDir.appendingPathComponent("1-1", isDirectory: true)
        try FileManager.default.createDirectory(at: oneOnOneDir, withIntermediateDirectories: true)

        let folder = FolderItem(
            name: "Standup",
            url: meetingDir,
            files: []
        )

        let destinations = FolderContentViewModel.listMoveDestinations(excluding: folder)
        let peopleDestinations = destinations.filter { $0.section != "Meetings" }

        XCTAssertEqual(peopleDestinations.count, 1)
        XCTAssertEqual(peopleDestinations.first?.name, "John (1-1)")
        XCTAssertEqual(peopleDestinations.first?.url.standardizedFileURL, oneOnOneDir.standardizedFileURL)
    }
}

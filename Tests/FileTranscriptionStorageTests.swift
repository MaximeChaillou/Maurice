import XCTest
@testable import Maurice

final class FileTranscriptionStorageTests: XCTestCase {

    private var tempDir: URL!
    private var storage: FileTranscriptionStorage!
    private var originalRootDirectory: String?

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = FileTranscriptionStorage()

        // Save original root directory and redirect to temp
        originalRootDirectory = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempDir.path, forKey: "rootDirectory")
    }

    override func tearDown() async throws {
        // Restore original root directory
        if let original = originalRootDirectory {
            UserDefaults.standard.set(original, forKey: "rootDirectory")
        } else {
            UserDefaults.standard.removeObject(forKey: "rootDirectory")
        }
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - formatTimestamp

    func testFormatTimestampZero() {
        XCTAssertEqual(FileTranscriptionStorage.formatTimestamp(0), "[00:00]")
    }

    func testFormatTimestampSeconds() {
        XCTAssertEqual(FileTranscriptionStorage.formatTimestamp(45), "[00:45]")
    }

    func testFormatTimestampMinutesAndSeconds() {
        XCTAssertEqual(FileTranscriptionStorage.formatTimestamp(125), "[02:05]")
    }

    func testFormatTimestampLargeValue() {
        // 90 minutes = 5400 seconds
        XCTAssertEqual(FileTranscriptionStorage.formatTimestamp(5400), "[90:00]")
    }

    func testFormatTimestampTruncatesDecimal() {
        XCTAssertEqual(FileTranscriptionStorage.formatTimestamp(61.9), "[01:01]")
    }

    // MARK: - header

    func testHeaderContainsPrefix() {
        let date = Date()
        let header = FileTranscriptionStorage.header(for: date)
        XCTAssertTrue(header.hasPrefix(FileTranscriptionStorage.headerPrefix))
    }

    func testHeaderContainsSeparator() {
        let date = Date()
        let header = FileTranscriptionStorage.header(for: date)
        XCTAssertTrue(header.contains(FileTranscriptionStorage.headerSeparator))
    }

    func testHeaderContainsFormattedDate() {
        let date = Date()
        let header = FileTranscriptionStorage.header(for: date)
        let expected = DateFormatters.dayAndTime.string(from: date)
        XCTAssertTrue(header.contains(expected))
    }

    // MARK: - beginLiveSession without subdirectory

    func testBeginLiveSessionCreatesFile() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "transcript")
    }

    func testBeginLiveSessionFileContainsHeader() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(content.hasPrefix(FileTranscriptionStorage.headerPrefix))
        XCTAssertTrue(content.contains(DateFormatters.dayAndTime.string(from: date)))
    }

    func testBeginLiveSessionFileNameMatchesDate() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let expected = "\(DateFormatters.dayOnly.string(from: date)).transcript"
        XCTAssertEqual(url.lastPathComponent, expected)
    }

    func testBeginLiveSessionWithoutSubdirectoryUseMeetingsDir() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        XCTAssertTrue(url.path.contains("Meetings"))
    }

    // MARK: - beginLiveSession with subdirectory

    func testBeginLiveSessionWithSubdirectoryCreatesInMeetingsSubfolder() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: "ProjectX")

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.path.contains("Meetings"))
        XCTAssertTrue(url.path.contains("ProjectX"))
    }

    func testBeginLiveSessionWithSubdirectoryCreatesNoteFile() throws {
        let date = Date()
        _ = try storage.beginLiveSession(startDate: date, subdirectory: "ProjectX")

        let noteFileName = "\(DateFormatters.dayOnly.string(from: date)).md"
        let meetingsDir = tempDir.appendingPathComponent("Meetings", isDirectory: true)
        let noteURL = meetingsDir.appendingPathComponent("ProjectX")
            .appendingPathComponent(noteFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: noteURL.path))
    }

    func testBeginLiveSessionWithPeopleSubdirectoryUsesRootDirectory() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: "People/Team/JohnDoe/1-1")

        XCTAssertTrue(url.path.contains("People/Team/JohnDoe/1-1"))
        // People/ prefix uses rootDirectory, not meetingsDirectory
        XCTAssertFalse(url.path.contains("Meetings"))
    }

    func testBeginLiveSessionAppendsSeparatorWhenFileExists() throws {
        let date = Date()
        let url1 = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let url2 = try storage.beginLiveSession(startDate: date, subdirectory: nil)

        XCTAssertEqual(url1, url2) // Same file
        let content = try String(contentsOf: url1, encoding: .utf8)
        XCTAssertTrue(content.contains("---"))
    }

    // MARK: - appendEntry

    func testAppendEntryWritesToFile() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let entry = TranscriptionEntry(text: "Hello world", timestamp: 30)

        try storage.appendEntry(entry, to: url)

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("[00:30]"))
        XCTAssertTrue(content.contains("Hello world"))
    }

    func testAppendMultipleEntries() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)

        try storage.appendEntry(TranscriptionEntry(text: "First", timestamp: 0), to: url)
        try storage.appendEntry(TranscriptionEntry(text: "Second", timestamp: 60), to: url)
        try storage.appendEntry(TranscriptionEntry(text: "Third", timestamp: 120), to: url)

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("First"))
        XCTAssertTrue(content.contains("Second"))
        XCTAssertTrue(content.contains("Third"))
        XCTAssertTrue(content.contains("[00:00]"))
        XCTAssertTrue(content.contains("[01:00]"))
        XCTAssertTrue(content.contains("[02:00]"))
    }

    // MARK: - parseTranscript edge cases

    func testParseTranscriptFileReturnsNilForNonExistentFile() {
        let fakeURL = tempDir.appendingPathComponent("nonexistent.txt")
        let result = storage.parseTranscriptFile(at: fakeURL)
        XCTAssertNil(result)
    }

    func testParseTranscriptFileReturnsNilForFileWithoutHeader() throws {
        let url = tempDir.appendingPathComponent("noheader.txt")
        try "Just some random content".write(to: url, atomically: true, encoding: .utf8)

        let result = storage.parseTranscriptFile(at: url)
        XCTAssertNil(result)
    }

    func testParseTranscriptFileReturnsTranscriptForValidFile() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        try storage.appendEntry(TranscriptionEntry(text: "Test entry", timestamp: 10), to: url)

        let result = storage.parseTranscriptFile(at: url)
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.entries.isEmpty)
    }

    func testParseTranscriptFileExtractsTextEntries() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        try storage.appendEntry(TranscriptionEntry(text: "Hello", timestamp: 5), to: url)
        try storage.appendEntry(TranscriptionEntry(text: "World", timestamp: 65), to: url)

        let result = storage.parseTranscriptFile(at: url)
        XCTAssertNotNil(result)

        let textEntries = result!.entries.compactMap { line -> String? in
            if case .text(let text, _) = line { return text }
            return nil
        }
        XCTAssertTrue(textEntries.contains("Hello"))
        XCTAssertTrue(textEntries.contains("World"))
    }

    func testParseTranscriptFileHandlesSeparators() throws {
        let date = Date()
        // Create two sessions in the same file
        _ = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)

        let result = storage.parseTranscriptFile(at: url)
        XCTAssertNotNil(result)

        let separators = result!.entries.compactMap { line -> String? in
            if case .separator(let text) = line { return text }
            return nil
        }
        XCTAssertFalse(separators.isEmpty)
    }

    func testParseTranscriptFileStripsTranscriptionPrefix() throws {
        let content = """
        \(FileTranscriptionStorage.headerPrefix)\(FileTranscriptionStorage.headerSeparator)2026-03-18 10:00

        [00:05]
        Some text
        """
        let url = tempDir.appendingPathComponent("transcription_my_file.txt")
        try content.write(to: url, atomically: true, encoding: .utf8)

        let result = storage.parseTranscriptFile(at: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "my file")
    }

    func testParseTranscriptFileUsesFileNameWithoutPrefix() throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)

        let result = storage.parseTranscriptFile(at: url)
        XCTAssertNotNil(result)
        // File name is date-based, no "transcription_" prefix
        XCTAssertEqual(result?.name, DateFormatters.dayOnly.string(from: date))
    }

    // MARK: - listDirectory

    func testListDirectoryReturnsEmptyForEmptyDir() {
        let emptyDir = tempDir.appendingPathComponent("empty", isDirectory: true)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let contents = storage.listDirectory(emptyDir)
        XCTAssertTrue(contents.transcripts.isEmpty)
        XCTAssertTrue(contents.folders.isEmpty)
    }

    func testListDirectoryScansFolders() {
        let dir = tempDir.appendingPathComponent("scan_test", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sub = dir.appendingPathComponent("SubFolder", isDirectory: true)
        try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

        let contents = storage.listDirectory(dir)
        XCTAssertEqual(contents.folders.count, 1)
        XCTAssertEqual(contents.folders.first?.name, "SubFolder")
    }

    // MARK: - delete

    func testDeleteRemovesFile() async throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let transcript = StoredTranscript(id: url, name: "test", date: date, entries: [])

        try await storage.delete(transcript)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - rename

    func testRenameMovesFile() async throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let transcript = StoredTranscript(id: url, name: "old", date: date, entries: [])

        let renamed = try await storage.rename(transcript, to: "new_name")
        XCTAssertEqual(renamed.name, "new_name")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.url.path))
    }

    func testRenameThrowsForEmptyName() async throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let transcript = StoredTranscript(id: url, name: "old", date: date, entries: [])

        do {
            _ = try await storage.rename(transcript, to: "   ")
            XCTFail("Expected invalidName error")
        } catch let error as StorageError {
            if case .invalidName = error {
                // expected
            } else {
                XCTFail("Expected invalidName, got \(error)")
            }
        }
    }

    func testRenameThrowsForDuplicateName() async throws {
        let date = Date()
        _ = try storage.beginLiveSession(startDate: date, subdirectory: nil)

        // Create a file named "existing.txt" in the same directory
        let meetingsDir = tempDir.appendingPathComponent("Meetings", isDirectory: true)
        let existingURL = meetingsDir.appendingPathComponent("existing.txt")
        try "content".write(to: existingURL, atomically: true, encoding: .utf8)

        _ = try storage.beginLiveSession(startDate: date, subdirectory: nil)

        // Rename a different file to "existing" which already exists
        // First create the source file with a .txt extension in the meetings dir
        let sourceURL = meetingsDir.appendingPathComponent("source.txt")
        try "source".write(to: sourceURL, atomically: true, encoding: .utf8)
        let sourceTranscript = StoredTranscript(
            id: sourceURL, name: "source", date: date, entries: []
        )

        do {
            _ = try await storage.rename(sourceTranscript, to: "existing")
            XCTFail("Expected duplicateName error")
        } catch let error as StorageError {
            if case .duplicateName(let name) = error {
                XCTAssertEqual(name, "existing")
            } else {
                XCTFail("Expected duplicateName, got \(error)")
            }
        }
    }

    func testRenameSanitizesInvalidCharacters() async throws {
        let date = Date()
        let url = try storage.beginLiveSession(startDate: date, subdirectory: nil)
        let transcript = StoredTranscript(id: url, name: "old", date: date, entries: [])

        let renamed = try await storage.rename(transcript, to: "file/with:bad*chars")
        XCTAssertEqual(renamed.name, "file-with-bad-chars")
    }
}

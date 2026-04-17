import XCTest
@testable import Maurice

final class MeetingDateEntryTests: XCTestCase {

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

    private func createFile(_ name: String, content: String = "content") {
        let url = tempDir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: content.data(using: .utf8))
    }

    private func createTranscriptFile(_ name: String) {
        let header = "Maurice Transcript \u{2014} 18 mars 2026 \u{00E0} 14:30"
        let content = """
        \(header)
        [0:05]
        Bonjour, ceci est un test.
        """
        createFile(name, content: content)
    }

    // MARK: - scan with .md files only

    func testScanWithMdFilesOnly() async {
        createFile("2024-01-15.md")
        createFile("2024-02-20.md")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0.hasNote })
        XCTAssertTrue(entries.allSatisfy { !$0.hasTranscript })
    }

    // MARK: - scan with .transcript files only

    func testScanWithTranscriptFilesOnly() async {
        createTranscriptFile("2024-03-10.transcript")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        XCTAssertEqual(entries.count, 1)
        XCTAssertFalse(entries[0].hasNote)
        XCTAssertTrue(entries[0].hasTranscript)
        XCTAssertEqual(entries[0].dateString, "2024-03-10")
    }

    // MARK: - scan with mixed .md and .transcript files

    func testScanWithMixedFiles() async {
        createFile("2024-01-15.md")
        createTranscriptFile("2024-01-15.transcript")
        createFile("2024-02-20.md")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        XCTAssertEqual(entries.count, 2)

        let jan15 = entries.first { $0.dateString == "2024-01-15" }
        XCTAssertNotNil(jan15)
        XCTAssertTrue(jan15!.hasNote)
        XCTAssertTrue(jan15!.hasTranscript)

        let feb20 = entries.first { $0.dateString == "2024-02-20" }
        XCTAssertNotNil(feb20)
        XCTAssertTrue(feb20!.hasNote)
        XCTAssertFalse(feb20!.hasTranscript)
    }

    // MARK: - scan with empty directory

    func testScanWithEmptyDirectory() async {
        let entries = await MeetingDateEntry.scan(in: tempDir)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - scan with non-existent directory

    func testScanWithNonExistentDirectory() async {
        let fakeDir = tempDir.appendingPathComponent("does-not-exist", isDirectory: true)
        let entries = await MeetingDateEntry.scan(in: fakeDir)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - date parsing from filenames

    func testDateParsingFromDateFilename() async {
        createFile("2024-06-15.md")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].dateString, "2024-06-15")

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: entries[0].date)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }

    func testNonDateFilenameStillScanned() async {
        createFile("notes-meeting.md")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].dateString, "notes-meeting")
    }

    // MARK: - sorting by date (descending)

    func testSortingByDateDescending() async {
        createFile("2024-01-01.md")
        createFile("2024-06-15.md")
        createFile("2024-03-10.md")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].dateString, "2024-06-15")
        XCTAssertEqual(entries[1].dateString, "2024-03-10")
        XCTAssertEqual(entries[2].dateString, "2024-01-01")
    }

    func testSortingWithManyDates() async {
        let dates = ["2023-12-31", "2024-01-01", "2024-12-25", "2024-07-04", "2023-06-01"]
        for date in dates {
            createFile("\(date).md")
        }

        let entries = await MeetingDateEntry.scan(in: tempDir)
        let dateStrings = entries.map(\.dateString)

        XCTAssertEqual(dateStrings, ["2024-12-25", "2024-07-04", "2024-01-01", "2023-12-31", "2023-06-01"])
    }

    // MARK: - Identifiable

    func testIdMatchesDateString() {
        let entry = MeetingDateEntry(dateString: "2024-01-01", date: Date(), noteFile: nil, transcript: nil)
        XCTAssertEqual(entry.id, "2024-01-01")
    }

    // MARK: - hasNote / hasTranscript

    func testHasNoteWhenNotePresent() {
        let url = tempDir.appendingPathComponent("test.md")
        let noteFile = FolderFile(id: url, name: "test", date: Date(), url: url)
        let entry = MeetingDateEntry(dateString: "2024-01-01", date: Date(), noteFile: noteFile, transcript: nil)

        XCTAssertTrue(entry.hasNote)
        XCTAssertFalse(entry.hasTranscript)
    }

    func testHasTranscriptWhenTranscriptPresent() {
        let url = tempDir.appendingPathComponent("test.transcript")
        let transcript = StoredTranscript(id: url, name: "test", date: Date(), entries: [])
        let entry = MeetingDateEntry(dateString: "2024-01-01", date: Date(), noteFile: nil, transcript: transcript)

        XCTAssertFalse(entry.hasNote)
        XCTAssertTrue(entry.hasTranscript)
    }

    func testHasBothNoteAndTranscript() {
        let noteURL = tempDir.appendingPathComponent("test.md")
        let transcriptURL = tempDir.appendingPathComponent("test.transcript")
        let noteFile = FolderFile(id: noteURL, name: "test", date: Date(), url: noteURL)
        let transcript = StoredTranscript(id: transcriptURL, name: "test", date: Date(), entries: [])
        let entry = MeetingDateEntry(
            dateString: "2024-01-01",
            date: Date(),
            noteFile: noteFile,
            transcript: transcript
        )

        XCTAssertTrue(entry.hasNote)
        XCTAssertTrue(entry.hasTranscript)
    }

    // MARK: - scan ignores non-md non-transcript files

    func testScanIgnoresOtherFileTypes() async {
        createFile("2024-01-01.md")
        createFile("2024-01-01.txt")
        createFile("2024-01-01.pdf")
        createFile("readme.md")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        // Should find 2 .md files: 2024-01-01.md and readme.md
        XCTAssertEqual(entries.count, 2)
        let dateStrings = Set(entries.map(\.dateString))
        XCTAssertTrue(dateStrings.contains("2024-01-01"))
        XCTAssertTrue(dateStrings.contains("readme"))
    }

    // MARK: - scan merges same-date note and transcript

    func testScanMergesSameDateNoteAndTranscript() async {
        createFile("2024-05-01.md")
        createTranscriptFile("2024-05-01.transcript")

        let entries = await MeetingDateEntry.scan(in: tempDir)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].dateString, "2024-05-01")
        XCTAssertTrue(entries[0].hasNote)
        XCTAssertTrue(entries[0].hasTranscript)
    }
}

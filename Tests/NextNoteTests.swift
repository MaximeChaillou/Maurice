import XCTest
@testable import Maurice

final class NextNoteTests: XCTestCase {

    private var tempDir: URL!
    private var nextFileURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        nextFileURL = tempDir.appendingPathComponent("next.md")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - URL construction

    func testNextFileURLIsCorrect() {
        let folderURL = URL(fileURLWithPath: "/tmp/Meetings/Standup")
        let nextURL = folderURL.appendingPathComponent("next.md")
        XCTAssertEqual(nextURL.lastPathComponent, "next.md")
        XCTAssertEqual(nextURL.deletingLastPathComponent().lastPathComponent, "Standup")
    }

    // MARK: - FolderFile convenience init from URL

    func testFolderFileFromNextURL() {
        FileManager.default.createFile(atPath: nextFileURL.path, contents: nil)
        let file = FolderFile(url: nextFileURL)
        XCTAssertEqual(file.name, "next")
        XCTAssertEqual(file.url, nextFileURL)
        XCTAssertEqual(file.id, nextFileURL)
    }

    func testFolderFileFromNonExistentURL() {
        let file = FolderFile(url: nextFileURL)
        XCTAssertEqual(file.name, "next")
        XCTAssertEqual(file.url, nextFileURL)
    }

    // MARK: - Content detection (mirrors NextNoteButton.checkContent)

    func testNoContentWhenFileDoesNotExist() {
        let hasContent = checkContent(nextFileURL)
        XCTAssertFalse(hasContent)
    }

    func testNoContentWhenFileIsEmpty() {
        FileManager.default.createFile(atPath: nextFileURL.path, contents: Data())
        let hasContent = checkContent(nextFileURL)
        XCTAssertFalse(hasContent)
    }

    func testNoContentWhenFileIsWhitespaceOnly() {
        try? "   \n\n  \t  ".write(to: nextFileURL, atomically: true, encoding: .utf8)
        let hasContent = checkContent(nextFileURL)
        XCTAssertFalse(hasContent)
    }

    func testHasContentWhenFileHasText() {
        try? "- Point à discuter".write(to: nextFileURL, atomically: true, encoding: .utf8)
        let hasContent = checkContent(nextFileURL)
        XCTAssertTrue(hasContent)
    }

    func testHasContentWithSingleCharacter() {
        try? "x".write(to: nextFileURL, atomically: true, encoding: .utf8)
        let hasContent = checkContent(nextFileURL)
        XCTAssertTrue(hasContent)
    }

    // MARK: - File creation (mirrors NextNoteButton.ensureFileExists)

    func testEnsureFileExistsCreatesFile() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: nextFileURL.path))
        ensureFileExists(nextFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nextFileURL.path))
    }

    func testEnsureFileExistsDoesNotOverwriteExisting() {
        let content = "Existing content"
        try? content.write(to: nextFileURL, atomically: true, encoding: .utf8)
        ensureFileExists(nextFileURL)
        let read = try? String(contentsOf: nextFileURL, encoding: .utf8)
        XCTAssertEqual(read, content)
    }

    // MARK: - FolderFile content and save

    func testFolderFileContentReadsFile() async {
        try? "Hello".write(to: nextFileURL, atomically: true, encoding: .utf8)
        let file = FolderFile(url: nextFileURL)
        let content = await file.loadContent()
        XCTAssertEqual(content, "Hello")
    }

    func testFolderFileContentEmptyWhenNoFile() async {
        let file = FolderFile(url: nextFileURL)
        let content = await file.loadContent()
        XCTAssertEqual(content, "")
    }

    func testFolderFileSaveWritesContent() async {
        FileManager.default.createFile(atPath: nextFileURL.path, contents: nil)
        let file = FolderFile(url: nextFileURL)
        await file.save(content: "New notes")
        let read = try? String(contentsOf: nextFileURL, encoding: .utf8)
        XCTAssertEqual(read, "New notes")
    }

    func testFolderFileSaveOverwritesPrevious() async {
        try? "Old".write(to: nextFileURL, atomically: true, encoding: .utf8)
        let file = FolderFile(url: nextFileURL)
        await file.save(content: "New")
        let content = await file.loadContent()
        XCTAssertEqual(content, "New")
    }

    // MARK: - Helpers (mirrors view logic)

    private func checkContent(_ url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func ensureFileExists(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }
}

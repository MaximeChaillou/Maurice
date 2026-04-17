import XCTest
@testable import Maurice

final class FolderFileTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FolderFileTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Init with URL

    func testInitWithURL() throws {
        let url = tempDir.appendingPathComponent("2026-03-27.md")
        try "Content".write(to: url, atomically: true, encoding: .utf8)

        let file = FolderFile(url: url)
        XCTAssertEqual(file.id, url)
        XCTAssertEqual(file.name, "2026-03-27")
        XCTAssertEqual(file.url, url)
    }

    func testInitWithURLUsesCurrentDate() throws {
        let url = tempDir.appendingPathComponent("test.md")
        try "Hello".write(to: url, atomically: true, encoding: .utf8)

        let before = Date()
        let file = FolderFile(url: url)
        let after = Date()
        XCTAssertGreaterThanOrEqual(file.date.timeIntervalSince1970, before.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(file.date.timeIntervalSince1970, after.timeIntervalSince1970)
    }

    // MARK: - Content

    func testContentReadsFile() async throws {
        let url = tempDir.appendingPathComponent("test.md")
        try "Hello World".write(to: url, atomically: true, encoding: .utf8)

        let file = FolderFile(url: url)
        let content = await file.loadContent()
        XCTAssertEqual(content, "Hello World")
    }

    func testContentForMissingFile() async {
        let url = tempDir.appendingPathComponent("nonexistent.md")
        let file = FolderFile(url: url)
        let content = await file.loadContent()
        XCTAssertEqual(content, "")
    }

    // MARK: - Save

    func testSaveCreatesFile() async throws {
        let url = tempDir.appendingPathComponent("new.md")
        let file = FolderFile(id: url, name: "new", date: Date(), url: url)
        await file.save(content: "Created content")

        let read = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(read, "Created content")
    }

    func testSaveOverwritesExisting() async throws {
        let url = tempDir.appendingPathComponent("existing.md")
        try "Old content".write(to: url, atomically: true, encoding: .utf8)

        let file = FolderFile(url: url)
        await file.save(content: "New content")

        let read = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(read, "New content")
    }

    // MARK: - Identity

    func testHashable() {
        let url1 = tempDir.appendingPathComponent("a.md")
        let url2 = tempDir.appendingPathComponent("b.md")
        let file1 = FolderFile(id: url1, name: "a", date: Date(), url: url1)
        let file2 = FolderFile(id: url2, name: "b", date: Date(), url: url2)
        let set: Set<FolderFile> = [file1, file2, file1]
        XCTAssertEqual(set.count, 2)
    }

    func testIdentifiable() {
        let url = tempDir.appendingPathComponent("test.md")
        let file = FolderFile(id: url, name: "test", date: Date(), url: url)
        XCTAssertEqual(file.id, url)
    }
}

import XCTest
@testable import Maurice

final class MemoryFileTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MemoryFileTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Frontmatter Parsing

    func testFrontmatterWithValidYAML() throws {
        let url = tempDir.appendingPathComponent("test.md")
        let content = """
        ---
        title: Hello
        tags: [a, b]
        ---

        Body content here.
        """
        try content.write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.frontmatter, "---\ntitle: Hello\ntags: [a, b]\n---")
    }

    func testFrontmatterWithNoFrontmatter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        try "Just plain text".write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.frontmatter, "")
    }

    func testFrontmatterWithUnclosedDelimiter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        let content = """
        ---
        title: Hello
        No closing delimiter
        """
        try content.write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.frontmatter, "")
    }

    func testFrontmatterWithEmptyFrontmatter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        let content = """
        ---
        ---

        Body only.
        """
        try content.write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.frontmatter, "---\n---")
    }

    // MARK: - Body Parsing

    func testBodyWithFrontmatter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        let content = """
        ---
        title: Hello
        ---

        Body content here.
        """
        try content.write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.body, "Body content here.")
    }

    func testBodyWithNoFrontmatter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        try "Just plain text".write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.body, "Just plain text")
    }

    func testBodyWithEmptyFrontmatter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        let content = """
        ---
        ---

        Body after empty frontmatter.
        """
        try content.write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.body, "Body after empty frontmatter.")
    }

    func testBodyTrimsWhitespace() throws {
        let url = tempDir.appendingPathComponent("test.md")
        let content = "---\ntitle: X\n---\n\n\n  Some body  \n\n"
        try content.write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.body, "Some body")
    }

    // MARK: - Save

    func testSaveWithFrontmatter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        let original = "---\ntitle: Hello\n---\n\nOriginal body."
        try original.write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        file.save(body: "Updated body.")

        let saved = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(saved.hasPrefix("---\ntitle: Hello\n---"))
        XCTAssertTrue(saved.contains("Updated body."))
    }

    func testSaveWithoutFrontmatter() throws {
        let url = tempDir.appendingPathComponent("test.md")
        try "Original".write(to: url, atomically: true, encoding: .utf8)

        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        file.save(body: "New content only.")

        let saved = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(saved, "New content only.")
    }

    // MARK: - Content for Missing File

    func testContentForMissingFile() {
        let url = tempDir.appendingPathComponent("nonexistent.md")
        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.content, "")
    }

    // MARK: - Identity

    func testIdentifiable() {
        let url = tempDir.appendingPathComponent("test.md")
        let file = MemoryFile(id: url, name: "test", folder: nil, date: Date(), url: url)
        XCTAssertEqual(file.id, url)
    }

    func testHashable() {
        let url1 = tempDir.appendingPathComponent("a.md")
        let url2 = tempDir.appendingPathComponent("b.md")
        let file1 = MemoryFile(id: url1, name: "a", folder: nil, date: Date(), url: url1)
        let file2 = MemoryFile(id: url2, name: "b", folder: nil, date: Date(), url: url2)
        let set: Set<MemoryFile> = [file1, file2]
        XCTAssertEqual(set.count, 2)
    }
}

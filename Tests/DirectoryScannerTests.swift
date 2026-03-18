import XCTest
@testable import Maurice

final class DirectoryScannerTests: XCTestCase {

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

    private func createFolder(_ name: String) {
        let url = tempDir.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func createFile(_ name: String, content: String = "test") {
        let url = tempDir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: content.data(using: .utf8))
    }

    // MARK: - Empty directory

    func testScanEmptyDirectoryReturnsEmptyContents() {
        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertTrue(contents.folders.isEmpty)
        XCTAssertTrue(contents.files.isEmpty)
    }

    // MARK: - Non-existent directory

    func testScanNonExistentDirectoryReturnsEmptyContents() {
        let fakeDir = tempDir.appendingPathComponent("does_not_exist", isDirectory: true)
        let contents = DirectoryScanner.scan(at: fakeDir)
        XCTAssertTrue(contents.folders.isEmpty)
        XCTAssertTrue(contents.files.isEmpty)
    }

    // MARK: - Folder vs file separation

    func testScanSeparatesFoldersAndFiles() {
        createFolder("MyFolder")
        createFile("document.md")

        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertEqual(contents.folders.count, 1)
        XCTAssertEqual(contents.files.count, 1)
        XCTAssertEqual(contents.folders.first?.name, "MyFolder")
        XCTAssertEqual(contents.files.first?.url.lastPathComponent, "document.md")
    }

    func testScanMultipleFoldersAndFiles() {
        createFolder("FolderA")
        createFolder("FolderB")
        createFile("file1.txt")
        createFile("file2.txt")
        createFile("file3.md")

        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertEqual(contents.folders.count, 2)
        XCTAssertEqual(contents.files.count, 3)
    }

    func testScanOnlyFolders() {
        createFolder("Alpha")
        createFolder("Beta")

        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertEqual(contents.folders.count, 2)
        XCTAssertTrue(contents.files.isEmpty)
    }

    func testScanOnlyFiles() {
        createFile("a.txt")
        createFile("b.md")

        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertTrue(contents.folders.isEmpty)
        XCTAssertEqual(contents.files.count, 2)
    }

    // MARK: - Extension filter

    func testScanWithExtensionFilterIncludesMatchingFilesOnly() {
        createFile("notes.md")
        createFile("data.txt")
        createFile("readme.md")

        let contents = DirectoryScanner.scan(at: tempDir, fileExtension: "md")
        XCTAssertEqual(contents.files.count, 2)

        let names = contents.files.map { $0.url.lastPathComponent }
        XCTAssertTrue(names.contains("notes.md"))
        XCTAssertTrue(names.contains("readme.md"))
        XCTAssertFalse(names.contains("data.txt"))
    }

    func testScanWithExtensionFilterStillIncludesFolders() {
        createFolder("SubDir")
        createFile("notes.md")
        createFile("data.txt")

        let contents = DirectoryScanner.scan(at: tempDir, fileExtension: "md")
        XCTAssertEqual(contents.folders.count, 1)
        XCTAssertEqual(contents.files.count, 1)
    }

    func testScanWithNoMatchingExtensionReturnsNoFiles() {
        createFile("doc.md")
        createFile("notes.txt")

        let contents = DirectoryScanner.scan(at: tempDir, fileExtension: "json")
        XCTAssertTrue(contents.files.isEmpty)
    }

    func testScanWithNilExtensionReturnsAllFiles() {
        createFile("a.md")
        createFile("b.txt")
        createFile("c.json")

        let contents = DirectoryScanner.scan(at: tempDir, fileExtension: nil)
        XCTAssertEqual(contents.files.count, 3)
    }

    // MARK: - Sorting

    func testFoldersSortedAlphabetically() {
        createFolder("Zebra")
        createFolder("Apple")
        createFolder("Mango")
        createFolder("banana")

        let contents = DirectoryScanner.scan(at: tempDir)
        let names = contents.folders.map(\.name)

        // localizedStandardCompare is case-insensitive
        XCTAssertEqual(names, ["Apple", "banana", "Mango", "Zebra"])
    }

    func testFoldersSortedWithNumbers() {
        createFolder("Item 10")
        createFolder("Item 2")
        createFolder("Item 1")

        let contents = DirectoryScanner.scan(at: tempDir)
        let names = contents.folders.map(\.name)

        // localizedStandardCompare sorts numbers naturally
        XCTAssertEqual(names, ["Item 1", "Item 2", "Item 10"])
    }

    // MARK: - Hidden files

    func testScanSkipsHiddenFiles() {
        createFile(".hidden")
        createFile("visible.txt")

        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertEqual(contents.files.count, 1)
        XCTAssertEqual(contents.files.first?.url.lastPathComponent, "visible.txt")
    }

    func testScanSkipsHiddenFolders() {
        createFolder(".hiddenFolder")
        createFolder("VisibleFolder")

        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertEqual(contents.folders.count, 1)
        XCTAssertEqual(contents.folders.first?.name, "VisibleFolder")
    }

    // MARK: - File dates

    func testFilesHaveModificationDates() {
        createFile("recent.txt")

        let contents = DirectoryScanner.scan(at: tempDir)
        XCTAssertEqual(contents.files.count, 1)

        let fileDate = contents.files.first?.date
        XCTAssertNotNil(fileDate)
        // Date should be very recent (within last minute)
        XCTAssertTrue(fileDate!.timeIntervalSinceNow > -60)
    }

    // MARK: - Async variant

    func testScanAsyncReturnsSameResultAsScan() async {
        createFolder("FolderX")
        createFile("file.md")

        let syncResult = DirectoryScanner.scan(at: tempDir)
        let asyncResult = await DirectoryScanner.scanAsync(at: tempDir)

        XCTAssertEqual(syncResult.folders.count, asyncResult.folders.count)
        XCTAssertEqual(syncResult.files.count, asyncResult.files.count)
        XCTAssertEqual(
            syncResult.folders.map(\.name),
            asyncResult.folders.map(\.name)
        )
    }
}

import XCTest
@testable import Maurice

@MainActor
final class HomeSetupCheckerTests: XCTestCase {
    private var tempDir: URL!
    private var savedRootDirectory: String?

    override func setUp() async throws {
        try await super.setUp()
        savedRootDirectory = UserDefaults.standard.string(forKey: "rootDirectory")
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("HomeSetupCheckerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        AppSettings.rootDirectory = tempDir
        try FileManager.default.createDirectory(
            at: AppSettings.memoryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        if let root = savedRootDirectory {
            UserDefaults.standard.set(root, forKey: "rootDirectory")
        } else {
            UserDefaults.standard.removeObject(forKey: "rootDirectory")
        }
        try await super.tearDown()
    }

    private func writeMemoryFile(_ name: String) throws {
        try "stub".write(
            to: AppSettings.memoryDirectory.appendingPathComponent(name),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Required files list

    func testRequiredMemoryFilesContainsExpectedThree() {
        XCTAssertEqual(
            Set(HomeSetupChecker.requiredMemoryFiles),
            Set(["Company.md", "Directory.md", "Lexicon.md"])
        )
    }

    // MARK: - Initial state

    func testInitialMemoryStatusIsZeroOfThree() {
        let sut = HomeSetupChecker()
        XCTAssertEqual(sut.memoryStatus.presentCount, 0)
        XCTAssertEqual(sut.memoryStatus.totalCount, 3)
        XCTAssertFalse(sut.memoryStatus.isComplete)
    }

    func testInitialConsoleStateIsChecking() {
        let sut = HomeSetupChecker()
        XCTAssertEqual(sut.consoleState, .checking)
    }

    // MARK: - Memory detection

    func testRefreshMemoryWithNoFilesReportsZero() {
        let sut = HomeSetupChecker()
        sut.refreshMemory()
        XCTAssertEqual(sut.memoryStatus.presentCount, 0)
        XCTAssertFalse(sut.memoryStatus.isComplete)
    }

    func testRefreshMemoryWithOneFileReportsOneOfThree() throws {
        try writeMemoryFile("Company.md")
        let sut = HomeSetupChecker()
        sut.refreshMemory()
        XCTAssertEqual(sut.memoryStatus.presentCount, 1)
        XCTAssertEqual(sut.memoryStatus.totalCount, 3)
        XCTAssertFalse(sut.memoryStatus.isComplete)
    }

    func testRefreshMemoryWithTwoFilesReportsTwoOfThree() throws {
        try writeMemoryFile("Company.md")
        try writeMemoryFile("Lexicon.md")
        let sut = HomeSetupChecker()
        sut.refreshMemory()
        XCTAssertEqual(sut.memoryStatus.presentCount, 2)
        XCTAssertFalse(sut.memoryStatus.isComplete)
    }

    func testRefreshMemoryWithAllThreeFilesReportsComplete() throws {
        try writeMemoryFile("Company.md")
        try writeMemoryFile("Directory.md")
        try writeMemoryFile("Lexicon.md")
        let sut = HomeSetupChecker()
        sut.refreshMemory()
        XCTAssertEqual(sut.memoryStatus.presentCount, 3)
        XCTAssertTrue(sut.memoryStatus.isComplete)
    }

    func testRefreshMemoryIgnoresUnrelatedFiles() throws {
        try writeMemoryFile("Other.md")
        try writeMemoryFile("notes.txt")
        let sut = HomeSetupChecker()
        sut.refreshMemory()
        XCTAssertEqual(sut.memoryStatus.presentCount, 0)
    }

    func testRefreshMemoryWithMissingMemoryDirectoryReportsZero() throws {
        try FileManager.default.removeItem(at: AppSettings.memoryDirectory)
        let sut = HomeSetupChecker()
        sut.refreshMemory()
        XCTAssertEqual(sut.memoryStatus.presentCount, 0)
        XCTAssertFalse(sut.memoryStatus.isComplete)
    }

    func testRefreshMemoryDoesNotCountSubdirectoryEntries() throws {
        let nested = AppSettings.memoryDirectory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "stub".write(
            to: nested.appendingPathComponent("Company.md"),
            atomically: true,
            encoding: .utf8
        )
        let sut = HomeSetupChecker()
        sut.refreshMemory()
        XCTAssertEqual(sut.memoryStatus.presentCount, 0)
    }

    // MARK: - MemoryStatus

    func testMemoryStatusCompleteRequiresNonZeroTotal() {
        let zeroStatus = HomeSetupChecker.MemoryStatus(presentCount: 0, totalCount: 0)
        XCTAssertFalse(zeroStatus.isComplete)
    }

    func testMemoryStatusCompleteWhenPresentMatchesTotal() {
        let status = HomeSetupChecker.MemoryStatus(presentCount: 3, totalCount: 3)
        XCTAssertTrue(status.isComplete)
    }

    func testMemoryStatusNotCompleteWhenPresentLessThanTotal() {
        let status = HomeSetupChecker.MemoryStatus(presentCount: 2, totalCount: 3)
        XCTAssertFalse(status.isComplete)
    }
}

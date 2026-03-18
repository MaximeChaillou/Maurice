import XCTest
@testable import Maurice

final class FolderNavigationStackTests: XCTestCase {

    private var rootDir: URL!
    private var sut: FolderNavigationStack!

    override func setUp() {
        super.setUp()
        rootDir = URL(fileURLWithPath: "/tmp/TestNavRoot", isDirectory: true)
        sut = FolderNavigationStack(rootDirectory: rootDir)
    }

    override func tearDown() {
        sut = nil
        rootDir = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialCurrentDirectoryIsRoot() {
        XCTAssertEqual(sut.currentDirectory, rootDir)
    }

    func testInitialCanGoBackIsFalse() {
        XCTAssertFalse(sut.canGoBack)
    }

    func testInitialDirectoryStackIsEmpty() {
        XCTAssertTrue(sut.directoryStack.isEmpty)
    }

    func testInitialRootDirectoryMatchesConstructor() {
        XCTAssertEqual(sut.rootDirectory, rootDir)
    }

    // MARK: - navigateInto

    func testNavigateIntoOneFolder() {
        let folder = Folder(url: rootDir.appendingPathComponent("Sub1", isDirectory: true))
        sut.navigateInto(folder)

        XCTAssertEqual(sut.currentDirectory, folder.url)
        XCTAssertTrue(sut.canGoBack)
        XCTAssertEqual(sut.directoryStack.count, 1)
    }

    func testNavigateIntoMultipleFolders() {
        let folder1 = Folder(url: rootDir.appendingPathComponent("A", isDirectory: true))
        let folder2 = Folder(url: folder1.url.appendingPathComponent("B", isDirectory: true))
        let folder3 = Folder(url: folder2.url.appendingPathComponent("C", isDirectory: true))

        sut.navigateInto(folder1)
        sut.navigateInto(folder2)
        sut.navigateInto(folder3)

        XCTAssertEqual(sut.currentDirectory, folder3.url)
        XCTAssertEqual(sut.directoryStack.count, 3)
        XCTAssertTrue(sut.canGoBack)
    }

    // MARK: - goBack

    func testGoBackFromOneLevel() {
        let folder = Folder(url: rootDir.appendingPathComponent("Sub", isDirectory: true))
        sut.navigateInto(folder)
        sut.goBack()

        XCTAssertEqual(sut.currentDirectory, rootDir)
        XCTAssertFalse(sut.canGoBack)
        XCTAssertTrue(sut.directoryStack.isEmpty)
    }

    func testGoBackFromTwoLevels() {
        let folder1 = Folder(url: rootDir.appendingPathComponent("A", isDirectory: true))
        let folder2 = Folder(url: folder1.url.appendingPathComponent("B", isDirectory: true))

        sut.navigateInto(folder1)
        sut.navigateInto(folder2)
        sut.goBack()

        XCTAssertEqual(sut.currentDirectory, folder1.url)
        XCTAssertTrue(sut.canGoBack)
        XCTAssertEqual(sut.directoryStack.count, 1)
    }

    func testGoBackOnEmptyStackDoesNothing() {
        sut.goBack()
        XCTAssertEqual(sut.currentDirectory, rootDir)
        XCTAssertFalse(sut.canGoBack)
    }

    func testGoBackMultipleTimesReturnsToRoot() {
        let folder1 = Folder(url: rootDir.appendingPathComponent("A", isDirectory: true))
        let folder2 = Folder(url: folder1.url.appendingPathComponent("B", isDirectory: true))
        let folder3 = Folder(url: folder2.url.appendingPathComponent("C", isDirectory: true))

        sut.navigateInto(folder1)
        sut.navigateInto(folder2)
        sut.navigateInto(folder3)

        sut.goBack()
        sut.goBack()
        sut.goBack()

        XCTAssertEqual(sut.currentDirectory, rootDir)
        XCTAssertFalse(sut.canGoBack)
    }

    // MARK: - reset

    func testResetClearsStack() {
        let folder1 = Folder(url: rootDir.appendingPathComponent("A", isDirectory: true))
        let folder2 = Folder(url: folder1.url.appendingPathComponent("B", isDirectory: true))

        sut.navigateInto(folder1)
        sut.navigateInto(folder2)
        sut.reset()

        XCTAssertEqual(sut.currentDirectory, rootDir)
        XCTAssertFalse(sut.canGoBack)
        XCTAssertTrue(sut.directoryStack.isEmpty)
    }

    func testResetOnEmptyStackIsNoOp() {
        sut.reset()
        XCTAssertEqual(sut.currentDirectory, rootDir)
        XCTAssertFalse(sut.canGoBack)
    }

    // MARK: - reset(to:)

    func testResetToNewRoot() {
        let folder = Folder(url: rootDir.appendingPathComponent("Sub", isDirectory: true))
        sut.navigateInto(folder)

        let newRoot = URL(fileURLWithPath: "/tmp/NewRoot", isDirectory: true)
        sut.reset(to: newRoot)

        XCTAssertEqual(sut.rootDirectory, newRoot)
        XCTAssertEqual(sut.currentDirectory, newRoot)
        XCTAssertTrue(sut.directoryStack.isEmpty)
        XCTAssertFalse(sut.canGoBack)
    }

    func testResetToNewRootClearsNavigationHistory() {
        let folder1 = Folder(url: rootDir.appendingPathComponent("A", isDirectory: true))
        let folder2 = Folder(url: folder1.url.appendingPathComponent("B", isDirectory: true))
        sut.navigateInto(folder1)
        sut.navigateInto(folder2)

        let newRoot = URL(fileURLWithPath: "/tmp/AnotherRoot", isDirectory: true)
        sut.reset(to: newRoot)

        XCTAssertEqual(sut.directoryStack.count, 0)
        XCTAssertEqual(sut.rootDirectory, newRoot)
    }

    // MARK: - currentDirectory computed property

    func testCurrentDirectoryReturnsRootWhenStackEmpty() {
        XCTAssertEqual(sut.currentDirectory, rootDir)
    }

    func testCurrentDirectoryReturnsLastFolder() {
        let folder1 = Folder(url: rootDir.appendingPathComponent("X", isDirectory: true))
        let folder2 = Folder(url: rootDir.appendingPathComponent("Y", isDirectory: true))

        sut.navigateInto(folder1)
        XCTAssertEqual(sut.currentDirectory, folder1.url)

        sut.navigateInto(folder2)
        XCTAssertEqual(sut.currentDirectory, folder2.url)
    }

    // MARK: - canGoBack computed property

    func testCanGoBackIsTrueWithOneItem() {
        let folder = Folder(url: rootDir.appendingPathComponent("F", isDirectory: true))
        sut.navigateInto(folder)
        XCTAssertTrue(sut.canGoBack)
    }

    func testCanGoBackIsFalseAfterGoingBackAll() {
        let folder = Folder(url: rootDir.appendingPathComponent("F", isDirectory: true))
        sut.navigateInto(folder)
        sut.goBack()
        XCTAssertFalse(sut.canGoBack)
    }

    // MARK: - Navigate then reset then navigate again

    func testNavigateAfterReset() {
        let folder1 = Folder(url: rootDir.appendingPathComponent("Old", isDirectory: true))
        sut.navigateInto(folder1)
        sut.reset()

        let folder2 = Folder(url: rootDir.appendingPathComponent("New", isDirectory: true))
        sut.navigateInto(folder2)

        XCTAssertEqual(sut.currentDirectory, folder2.url)
        XCTAssertEqual(sut.directoryStack.count, 1)
    }
}

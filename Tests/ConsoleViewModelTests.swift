import XCTest
@testable import Maurice

@MainActor
final class ConsoleViewModelTests: XCTestCase {

    private var sut: ConsoleViewModel!

    override func setUp() async throws {
        try await super.setUp()
        sut = ConsoleViewModel()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsNotRunning() {
        XCTAssertFalse(sut.isRunning)
    }

    func testInitialStateHasNoError() {
        XCTAssertNil(sut.errorMessage)
    }

    func testInitialShouldExpandIsFalse() {
        XCTAssertFalse(sut.shouldExpand)
    }

    // MARK: - sendSkill

    func testSendSkillSetsShouldExpand() {
        sut.sendSkill(filename: "test.md")
        XCTAssertTrue(sut.shouldExpand)
    }

    func testSendSkillWithParameterSetsShouldExpand() {
        sut.sendSkill(filename: "test.md", parameter: "/some/path")
        XCTAssertTrue(sut.shouldExpand)
    }

    func testSendImportSkillSetsShouldExpand() {
        sut.sendImportSkill(source: "/tmp/doc.pdf", targetPath: "/tmp/out.md")
        XCTAssertTrue(sut.shouldExpand)
    }

    // MARK: - processTerminated

    func testProcessTerminatedSetsNotRunning() {
        sut.processTerminated()
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - startSessionIfNeeded without terminal

    func testStartSessionIfNeededWithoutTerminalDoesNotCrash() {
        sut.startSessionIfNeeded()
        // Should not crash, just no-op (no terminalView)
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - focusTerminal without terminal

    func testFocusTerminalWithoutTerminalDoesNotCrash() {
        sut.focusTerminal()
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - sendCommand without running

    func testSendCommandWhenNotRunningIsNoOp() {
        // Should not crash when not running
        sut.sendCommand("hello")
        XCTAssertFalse(sut.isRunning)
    }

    func testStopWhenNotRunningIsNoOp() {
        // Should not crash
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }
}

import XCTest
@testable import Maurice

@MainActor
final class SkillRunnerTests: XCTestCase {

    private var sut: SkillRunner!

    override func setUp() async throws {
        try await super.setUp()
        sut = SkillRunner()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - formatToolCall with valid JSON

    func testFormatToolCallReadWithFilePath() {
        let json = """
        {"file_path": "/Users/test/Documents/note.md"}
        """
        let result = sut.formatToolCall(name: "Read", inputJSON: json)
        XCTAssertEqual(result, "[outil] Read — note.md")
    }

    func testFormatToolCallEditWithFilePath() {
        let json = """
        {"file_path": "/Users/test/project/main.swift", "old_string": "foo", "new_string": "bar"}
        """
        let result = sut.formatToolCall(name: "Edit", inputJSON: json)
        XCTAssertEqual(result, "[outil] Edit — main.swift")
    }

    func testFormatToolCallWriteWithFilePath() {
        let json = """
        {"file_path": "/tmp/output.txt", "content": "hello"}
        """
        let result = sut.formatToolCall(name: "Write", inputJSON: json)
        XCTAssertEqual(result, "[outil] Write — output.txt")
    }

    func testFormatToolCallBashWithCommand() {
        let json = """
        {"command": "ls -la /Users/test/Documents"}
        """
        let result = sut.formatToolCall(name: "Bash", inputJSON: json)
        XCTAssertEqual(result, "[outil] Bash — ls -la /Users/test/Documents")
    }

    func testFormatToolCallBashTruncatesLongCommand() {
        let longCommand = String(repeating: "a", count: 120)
        let json = """
        {"command": "\(longCommand)"}
        """
        let result = sut.formatToolCall(name: "Bash", inputJSON: json)
        let expectedPrefix = "[outil] Bash — " + String(repeating: "a", count: 80)
        XCTAssertEqual(result, expectedPrefix)
    }

    func testFormatToolCallGrepWithPattern() {
        let json = """
        {"pattern": "TODO|FIXME"}
        """
        let result = sut.formatToolCall(name: "Grep", inputJSON: json)
        XCTAssertEqual(result, "[outil] Grep — \"TODO|FIXME\"")
    }

    func testFormatToolCallGlobWithPattern() {
        let json = """
        {"pattern": "**/*.swift"}
        """
        let result = sut.formatToolCall(name: "Glob", inputJSON: json)
        XCTAssertEqual(result, "[outil] Glob — **/*.swift")
    }

    // MARK: - formatToolCall with invalid / empty JSON

    func testFormatToolCallWithInvalidJSON() {
        let result = sut.formatToolCall(name: "Read", inputJSON: "not json")
        XCTAssertEqual(result, "[outil] Read")
    }

    func testFormatToolCallWithEmptyJSON() {
        let result = sut.formatToolCall(name: "Read", inputJSON: "")
        XCTAssertEqual(result, "[outil] Read")
    }

    func testFormatToolCallWithEmptyParams() {
        let result = sut.formatToolCall(name: "UnknownTool", inputJSON: "{}")
        XCTAssertEqual(result, "[outil] UnknownTool")
    }

    // MARK: - toolSummary

    func testToolSummaryReadExtractsLastPathComponent() {
        let params: [String: Any] = ["file_path": "/a/b/c/file.swift"]
        let result = sut.toolSummary(name: "Read", params: params)
        XCTAssertEqual(result, "file.swift")
    }

    func testToolSummaryEditExtractsLastPathComponent() {
        let params: [String: Any] = ["file_path": "/project/Sources/App.swift", "old_string": "x"]
        let result = sut.toolSummary(name: "Edit", params: params)
        XCTAssertEqual(result, "App.swift")
    }

    func testToolSummaryWriteExtractsLastPathComponent() {
        let params: [String: Any] = ["file_path": "/tmp/output.json", "content": "data"]
        let result = sut.toolSummary(name: "Write", params: params)
        XCTAssertEqual(result, "output.json")
    }

    func testToolSummaryBashExtractsCommand() {
        let params: [String: Any] = ["command": "git status"]
        let result = sut.toolSummary(name: "Bash", params: params)
        XCTAssertEqual(result, "git status")
    }

    func testToolSummaryBashTruncatesAt80Chars() {
        let longCmd = String(repeating: "x", count: 100)
        let params: [String: Any] = ["command": longCmd]
        let result = sut.toolSummary(name: "Bash", params: params)
        XCTAssertEqual(result.count, 80)
    }

    func testToolSummaryGrepWrapsPatternInQuotes() {
        let params: [String: Any] = ["pattern": "func test"]
        let result = sut.toolSummary(name: "Grep", params: params)
        XCTAssertEqual(result, "\"func test\"")
    }

    func testToolSummaryGlobReturnsPatternDirectly() {
        let params: [String: Any] = ["pattern": "*.md"]
        let result = sut.toolSummary(name: "Glob", params: params)
        XCTAssertEqual(result, "*.md")
    }

    func testToolSummaryUnknownToolWithStringParams() {
        let params: [String: Any] = ["key1": "value1", "key2": "value2"]
        let result = sut.toolSummary(name: "Custom", params: params)
        // Should contain key-value pairs
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("key1: value1") || result.contains("key2: value2"))
    }

    func testToolSummaryUnknownToolWithNoStringParams() {
        let params: [String: Any] = ["count": 42, "flag": true]
        let result = sut.toolSummary(name: "Custom", params: params)
        XCTAssertEqual(result, "")
    }

    func testToolSummaryEmptyParams() {
        let result = sut.toolSummary(name: "Read", params: [:])
        XCTAssertEqual(result, "")
    }

    func testToolSummaryUnknownToolTruncatesLongValues() {
        let longValue = String(repeating: "z", count: 100)
        let params: [String: Any] = ["data": longValue]
        let result = sut.toolSummary(name: "Custom", params: params)
        XCTAssertTrue(result.contains("data: "))
        // Value should be truncated to 50 chars
        let valueStart = result.index(result.startIndex, offsetBy: "data: ".count)
        let extractedValue = String(result[valueStart...])
        XCTAssertEqual(extractedValue.count, 50)
    }

    // MARK: - mauricePermissions

    func testMauricePermissionsContainsReadWriteEditGlobGrepBash() {
        let permissions = SkillRunner.mauricePermissions
        let root = AppSettings.rootDirectory.path

        XCTAssertTrue(permissions.contains("Read(\(root)/**)"))
        XCTAssertTrue(permissions.contains("Write(\(root)/**)"))
        XCTAssertTrue(permissions.contains("Edit(\(root)/**)"))
        XCTAssertTrue(permissions.contains("Glob(\(root)/**)"))
        XCTAssertTrue(permissions.contains("Grep(\(root)/**)"))
        XCTAssertTrue(permissions.contains("Bash(ls:*,mkdir:*,cat:*,mv:*,cp:*,rm:*)"))
    }

    func testMauricePermissionsAlternatesAllowedToolsFlag() {
        let permissions = SkillRunner.mauricePermissions
        // Every even index should be "--allowedTools"
        for index in stride(from: 0, to: permissions.count, by: 2) {
            XCTAssertEqual(permissions[index], "--allowedTools")
        }
    }

    func testMauricePermissionsHasSixPairs() {
        let permissions = SkillRunner.mauricePermissions
        // 6 tools: Read, Write, Edit, Glob, Grep, Bash -> 12 elements (flag + value each)
        XCTAssertEqual(permissions.count, 12)
    }

    // MARK: - Initial state

    func testInitialState() {
        XCTAssertTrue(sut.outputLines.isEmpty)
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(sut.lastAssistantLine, "")
        XCTAssertEqual(sut.currentText, "")
        XCTAssertNil(sut.actionID)
        XCTAssertNil(sut.skillLabel)
    }
}

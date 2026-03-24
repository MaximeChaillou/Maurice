import XCTest
@testable import Maurice

final class IssueLoggerTests: XCTestCase {

    private var tempDir: URL!
    private var savedRootDirectory: String?

    private var logFileURL: URL {
        tempDir.appendingPathComponent(".maurice/issues.log")
    }

    private var oldLogFileURL: URL {
        tempDir.appendingPathComponent(".maurice/issues.old.log")
    }

    override func setUp() {
        super.setUp()
        savedRootDirectory = UserDefaults.standard.string(forKey: "rootDirectory")
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IssueLoggerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        AppSettings.rootDirectory = tempDir
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        if let root = savedRootDirectory {
            UserDefaults.standard.set(root, forKey: "rootDirectory")
        } else {
            UserDefaults.standard.removeObject(forKey: "rootDirectory")
        }
        super.tearDown()
    }

    // MARK: - Basic logging

    func testLogCreatesFileAndWritesEntry() {
        let expectation = expectation(description: "Log written")

        IssueLogger.log(.error, "Test error message")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path))
        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("[ERROR]") == true)
        XCTAssertTrue(content?.contains("Test error message") == true)
    }

    func testLogIncludesContext() {
        let expectation = expectation(description: "Log written")

        IssueLogger.log(.warning, "Context test", context: "/some/path")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(content?.contains("[WARNING]") == true)
        XCTAssertTrue(content?.contains("context: /some/path") == true)
    }

    func testLogIncludesError() {
        let expectation = expectation(description: "Log written")

        let testError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "something broke"])
        IssueLogger.log(.error, "Error test", error: testError)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(content?.contains("error: something broke") == true)
    }

    func testLogIncludesSourceFileAndLine() {
        let expectation = expectation(description: "Log written")

        IssueLogger.log(.error, "Source test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(content?.contains("IssueLoggerTests.swift:") == true)
    }

    // MARK: - Crash logging (synchronous)

    func testLogCrashWritesSynchronously() {
        IssueLogger.logCrash("Fatal crash test")

        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path))
        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(content?.contains("[CRASH]") == true)
        XCTAssertTrue(content?.contains("Fatal crash test") == true)
    }

    // MARK: - Append behavior

    func testMultipleLogsAppend() {
        let expectation = expectation(description: "Logs written")

        IssueLogger.logCrash("First entry")
        IssueLogger.logCrash("Second entry")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(content?.contains("First entry") == true)
        XCTAssertTrue(content?.contains("Second entry") == true)

        let lines = content?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertEqual(lines.count, 2)
    }

    // MARK: - Directory creation

    func testLogCreatesDirectoryIfMissing() {
        let mauriceDir = tempDir.appendingPathComponent(".maurice")
        try? FileManager.default.removeItem(at: mauriceDir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: mauriceDir.path))

        IssueLogger.logCrash("Directory creation test")

        XCTAssertTrue(FileManager.default.fileExists(atPath: mauriceDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path))
    }

    // MARK: - Log rotation

    func testRotateMovesFileWhenOverMaxSize() {
        // Create .maurice directory
        let mauriceDir = tempDir.appendingPathComponent(".maurice")
        try? FileManager.default.createDirectory(at: mauriceDir, withIntermediateDirectories: true)

        // Create a file just over 2MB
        let bigData = Data(repeating: 65, count: 2 * 1024 * 1024 + 1)
        FileManager.default.createFile(atPath: logFileURL.path, contents: bigData)

        let expectation = expectation(description: "Log with rotation")

        IssueLogger.log(.error, "After rotation")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        // Old file should exist (rotated)
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldLogFileURL.path))
        // New log file should exist with new entry
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path))
        let newContent = try? String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(newContent?.contains("After rotation") == true)
    }

    // MARK: - Level raw values

    func testIssueLevelRawValues() {
        XCTAssertEqual(IssueLevel.error.rawValue, "ERROR")
        XCTAssertEqual(IssueLevel.warning.rawValue, "WARNING")
        XCTAssertEqual(IssueLevel.crash.rawValue, "CRASH")
    }

    // MARK: - Timestamp format

    func testLogContainsISO8601Timestamp() {
        IssueLogger.logCrash("Timestamp test")

        let content = try? String(contentsOf: logFileURL, encoding: .utf8)
        // ISO8601 format: [2026-03-24T...]
        let regex = try? NSRegularExpression(pattern: "\\[\\d{4}-\\d{2}-\\d{2}T")
        let range = NSRange(location: 0, length: (content ?? "").utf16.count)
        let match = regex?.firstMatch(in: content ?? "", range: range)
        XCTAssertNotNil(match)
    }
}

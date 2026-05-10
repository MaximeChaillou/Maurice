import XCTest
@testable import Maurice

final class ClaudeBinaryLocatorTests: XCTestCase {
    func testFindReturnsExecutablePathOrNil() {
        let result = ClaudeBinaryLocator.find()
        if let path = result {
            XCTAssertTrue(
                FileManager.default.isExecutableFile(atPath: path),
                "Returned path should point to an executable file: \(path)"
            )
        }
    }

    func testFindIsIdempotent() {
        let first = ClaudeBinaryLocator.find()
        let second = ClaudeBinaryLocator.find()
        XCTAssertEqual(first, second)
    }
}

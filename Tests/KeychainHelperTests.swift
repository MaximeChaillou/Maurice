import XCTest
@testable import Maurice

final class KeychainHelperTests: XCTestCase {
    private let service = "com.maurice.test.keychain-\(UUID().uuidString)"
    private let account = "test-account"

    override func tearDown() {
        KeychainHelper.delete(service: service, account: account)
        super.tearDown()
    }

    // MARK: - Save & Load

    func testSaveAndLoadRoundtrip() throws {
        let data = "Hello, Keychain!".data(using: .utf8)!
        try KeychainHelper.save(data: data, service: service, account: account)

        let loaded = KeychainHelper.load(service: service, account: account)
        XCTAssertEqual(loaded, data)
    }

    func testSaveOverwritesExisting() throws {
        let data1 = "First".data(using: .utf8)!
        let data2 = "Second".data(using: .utf8)!

        try KeychainHelper.save(data: data1, service: service, account: account)
        try KeychainHelper.save(data: data2, service: service, account: account)

        let loaded = KeychainHelper.load(service: service, account: account)
        XCTAssertEqual(loaded, data2)
    }

    // MARK: - Load Missing

    func testLoadMissingReturnsNil() {
        let loaded = KeychainHelper.load(service: service, account: "nonexistent-account")
        XCTAssertNil(loaded)
    }

    // MARK: - Delete

    func testDeleteRemovesItem() throws {
        let data = "ToDelete".data(using: .utf8)!
        try KeychainHelper.save(data: data, service: service, account: account)

        KeychainHelper.delete(service: service, account: account)

        let loaded = KeychainHelper.load(service: service, account: account)
        XCTAssertNil(loaded)
    }

    func testDeleteNonExistentDoesNotThrow() {
        // Should not crash
        KeychainHelper.delete(service: service, account: "does-not-exist")
    }

    // MARK: - Error

    func testKeychainErrorHasStatus() {
        let error = KeychainError.unhandledError(status: -25300)
        if case .unhandledError(let status) = error {
            XCTAssertEqual(status, -25300)
        } else {
            XCTFail("Expected unhandledError case")
        }
    }
}

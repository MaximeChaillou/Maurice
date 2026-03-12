import XCTest
@testable import Maurice

final class CodableColorTests: XCTestCase {

    // MARK: - Init from NSColor

    func testInitFromNSColor() {
        let color = CodableColor(NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.8))
        XCTAssertEqual(color.red, 0.2, accuracy: 0.001)
        XCTAssertEqual(color.green, 0.4, accuracy: 0.001)
        XCTAssertEqual(color.blue, 0.6, accuracy: 0.001)
        XCTAssertEqual(color.alpha, 0.8, accuracy: 0.001)
    }

    func testInitFromNSColorConvertsColorSpace() {
        // Device RGB should be converted to sRGB
        let deviceColor = NSColor(deviceRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let codable = CodableColor(deviceColor)
        XCTAssertEqual(codable.alpha, 1.0, accuracy: 0.01)
        XCTAssertTrue(codable.red > 0.5) // Should be roughly red
    }

    // MARK: - Init with components

    func testInitWithComponents() {
        let color = CodableColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        XCTAssertEqual(color.red, 0.1)
        XCTAssertEqual(color.green, 0.2)
        XCTAssertEqual(color.blue, 0.3)
        XCTAssertEqual(color.alpha, 0.4)
    }

    func testInitWithComponentsDefaultAlpha() {
        let color = CodableColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(color.alpha, 1.0)
    }

    // MARK: - nsColor

    func testNsColorRoundtrip() {
        let original = CodableColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.9)
        let ns = original.nsColor
        let roundtripped = CodableColor(ns)
        XCTAssertEqual(roundtripped.red, original.red, accuracy: 0.001)
        XCTAssertEqual(roundtripped.green, original.green, accuracy: 0.001)
        XCTAssertEqual(roundtripped.blue, original.blue, accuracy: 0.001)
        XCTAssertEqual(roundtripped.alpha, original.alpha, accuracy: 0.001)
    }

    // MARK: - color (SwiftUI)

    func testColorProperty() {
        let codable = CodableColor(red: 1, green: 0, blue: 0)
        // Just verify it doesn't crash — Color is opaque
        _ = codable.color
    }

    // MARK: - Codable roundtrip

    func testCodableRoundtrip() throws {
        let original = CodableColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableColor.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = CodableColor(red: 1, green: 0, blue: 0)
        let b = CodableColor(red: 1, green: 0, blue: 0)
        let c = CodableColor(red: 0, green: 1, blue: 0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

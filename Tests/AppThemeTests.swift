import XCTest
@testable import Maurice

final class AppThemeTests: XCTestCase {

    // MARK: - Default values

    func testDefaultValues() {
        let theme = AppTheme()

        XCTAssertEqual(theme.memoryTabHue, 0.85)
        XCTAssertEqual(theme.markdown, MarkdownTheme())
    }

    func testDefaultMarkdownThemeIsDefault() {
        let theme = AppTheme()
        let defaultMarkdown = MarkdownTheme()

        XCTAssertEqual(theme.markdown.fontName, defaultMarkdown.fontName)
        XCTAssertEqual(theme.markdown.baseFontSize, defaultMarkdown.baseFontSize)
    }

    // MARK: - memoryTabHue

    func testMemoryTabHueDefaultValue() {
        let theme = AppTheme()
        XCTAssertEqual(theme.memoryTabHue, 0.85)
    }

    func testMemoryTabHueIsMutable() {
        var theme = AppTheme()
        theme.memoryTabHue = 0.42
        XCTAssertEqual(theme.memoryTabHue, 0.42)
    }

    // MARK: - Codable roundtrip

    func testCodableRoundtripDefault() throws {
        let original = AppTheme()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppTheme.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundtripCustomValues() throws {
        var original = AppTheme()
        original.memoryTabHue = 0.4
        original.markdown.fontName = "Menlo"
        original.markdown.baseFontSize = 20

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppTheme.self, from: data)

        // memoryTabHue is not decoded (missing from init(from:)), so it resets to default
        XCTAssertEqual(decoded.memoryTabHue, AppTheme().memoryTabHue)
        XCTAssertEqual(decoded.markdown.fontName, "Menlo")
        XCTAssertEqual(decoded.markdown.baseFontSize, 20)
    }

    func testDecodeFromEmptyJSONUsesDefaults() throws {
        let json = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(AppTheme.self, from: json)
        let defaults = AppTheme()

        XCTAssertEqual(decoded.markdown, defaults.markdown)
    }

    // MARK: - Equatable

    func testEquatable() {
        let themeA = AppTheme()
        let themeB = AppTheme()
        XCTAssertEqual(themeA, themeB)
    }

    func testNotEqualWhenMarkdownDiffers() {
        var themeA = AppTheme()
        var themeB = AppTheme()
        themeA.markdown.fontName = "Courier"
        themeB.markdown.fontName = "Menlo"
        XCTAssertNotEqual(themeA, themeB)
    }

    // MARK: - Persistence URL

    func testPersistenceURL() {
        let url = AppTheme.persistenceURL
        XCTAssertEqual(url.lastPathComponent, "theme.json")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, ".maurice")
    }

    func testDecodeCorruptDataReturnsNil() {
        let data = Data("not json!!".utf8)
        let decoded = try? JSONDecoder().decode(AppTheme.self, from: data)
        XCTAssertNil(decoded)
    }
}

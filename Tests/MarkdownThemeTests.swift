import XCTest
@testable import Maurice

final class MarkdownThemeTests: XCTestCase {

    // MARK: - Default values

    func testDefaultInit() {
        let theme = MarkdownTheme()
        XCTAssertEqual(theme.fontName, "System")
        XCTAssertEqual(theme.baseFontSize, 14)
        XCTAssertEqual(theme.h1FontSize, 26)
        XCTAssertEqual(theme.h2FontSize, 20)
        XCTAssertEqual(theme.h3FontSize, 17)
        XCTAssertTrue(theme.h1Bold)
        XCTAssertFalse(theme.h1Italic)
        XCTAssertFalse(theme.h1Underline)
        XCTAssertTrue(theme.h2Bold)
        XCTAssertFalse(theme.h2Italic)
        XCTAssertFalse(theme.h2Underline)
        XCTAssertTrue(theme.h3Bold)
        XCTAssertFalse(theme.h3Italic)
        XCTAssertFalse(theme.h3Underline)
        XCTAssertFalse(theme.quoteBold)
        XCTAssertTrue(theme.quoteItalic)
        XCTAssertFalse(theme.quoteUnderline)
        XCTAssertEqual(theme.maxContentWidth, 700)
    }

    // MARK: - Codable roundtrip

    func testFullRoundtrip() throws {
        var theme = MarkdownTheme()
        theme.fontName = "Menlo"
        theme.baseFontSize = 16
        theme.h1FontSize = 30
        theme.h1Bold = false
        theme.h1Italic = true
        theme.h1Underline = true
        theme.h2FontSize = 24
        theme.h2Bold = false
        theme.h2Italic = true
        theme.h2Underline = true
        theme.h3FontSize = 18
        theme.h3Bold = false
        theme.h3Italic = true
        theme.h3Underline = true
        theme.quoteBold = true
        theme.quoteItalic = false
        theme.quoteUnderline = true
        theme.maxContentWidth = 800
        theme.bodyColor = CodableColor(red: 1, green: 0, blue: 0)
        theme.boldColor = CodableColor(red: 0, green: 1, blue: 0)
        theme.italicColor = CodableColor(red: 0, green: 0, blue: 1)
        theme.codeColor = CodableColor(red: 0.5, green: 0.5, blue: 0.5)
        theme.codeBackgroundColor = CodableColor(red: 0.1, green: 0.1, blue: 0.1)
        theme.dividerColor = CodableColor(red: 0.8, green: 0.8, blue: 0.8)
        theme.backgroundColor = CodableColor(red: 0, green: 0, blue: 0)

        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(MarkdownTheme.self, from: data)
        XCTAssertEqual(decoded, theme)
    }

    // MARK: - Decode with missing keys uses defaults

    func testDecodeEmptyJSON() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MarkdownTheme.self, from: json)
        let defaults = MarkdownTheme()
        XCTAssertEqual(decoded.fontName, defaults.fontName)
        XCTAssertEqual(decoded.baseFontSize, defaults.baseFontSize)
        XCTAssertEqual(decoded.h1FontSize, defaults.h1FontSize)
        XCTAssertEqual(decoded.h1Bold, defaults.h1Bold)
        XCTAssertEqual(decoded.h1Italic, defaults.h1Italic)
        XCTAssertEqual(decoded.h1Underline, defaults.h1Underline)
        XCTAssertEqual(decoded.h2FontSize, defaults.h2FontSize)
        XCTAssertEqual(decoded.h2Bold, defaults.h2Bold)
        XCTAssertEqual(decoded.h2Italic, defaults.h2Italic)
        XCTAssertEqual(decoded.h2Underline, defaults.h2Underline)
        XCTAssertEqual(decoded.h3FontSize, defaults.h3FontSize)
        XCTAssertEqual(decoded.h3Bold, defaults.h3Bold)
        XCTAssertEqual(decoded.h3Italic, defaults.h3Italic)
        XCTAssertEqual(decoded.h3Underline, defaults.h3Underline)
        XCTAssertEqual(decoded.quoteBold, defaults.quoteBold)
        XCTAssertEqual(decoded.quoteItalic, defaults.quoteItalic)
        XCTAssertEqual(decoded.quoteUnderline, defaults.quoteUnderline)
        XCTAssertEqual(decoded.maxContentWidth, defaults.maxContentWidth)
        XCTAssertEqual(decoded.bodyColor, defaults.bodyColor)
        XCTAssertEqual(decoded.boldColor, defaults.boldColor)
        XCTAssertEqual(decoded.italicColor, defaults.italicColor)
        XCTAssertEqual(decoded.quoteColor, defaults.quoteColor)
        XCTAssertEqual(decoded.codeColor, defaults.codeColor)
        XCTAssertEqual(decoded.codeBackgroundColor, defaults.codeBackgroundColor)
        XCTAssertEqual(decoded.dividerColor, defaults.dividerColor)
        XCTAssertEqual(decoded.backgroundColor, defaults.backgroundColor)
    }

    func testDecodePartialJSON() throws {
        let json = """
        {"fontName": "Courier", "baseFontSize": 18, "h1Bold": false}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MarkdownTheme.self, from: json)
        XCTAssertEqual(decoded.fontName, "Courier")
        XCTAssertEqual(decoded.baseFontSize, 18)
        XCTAssertFalse(decoded.h1Bold)
        // Rest should be defaults
        XCTAssertEqual(decoded.h1FontSize, 26)
        XCTAssertTrue(decoded.h2Bold)
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = MarkdownTheme()
        var b = MarkdownTheme()
        XCTAssertEqual(a, b)
        b.fontName = "Menlo"
        XCTAssertNotEqual(a, b)
    }

    // MARK: - AppTheme persistence URL

    func testAppThemePersistenceURL() {
        let url = AppTheme.persistenceURL
        XCTAssertTrue(url.lastPathComponent == "theme.json")
    }

    // MARK: - AppTheme Save / Load roundtrip

    func testAppThemeSaveAndLoad() {
        var appTheme = AppTheme.load()
        appTheme.markdown.fontName = "TestFont_SaveLoad"
        appTheme.save()

        let loaded = AppTheme.load()
        XCTAssertEqual(loaded.markdown.fontName, "TestFont_SaveLoad")

        // Restore defaults
        let defaults = AppTheme()
        defaults.save()
    }

    func testAppThemeLoadMissingFileReturnsDefault() {
        let url = AppTheme.persistenceURL
        let backup = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)

        let loaded = AppTheme.load()
        XCTAssertEqual(loaded.markdown.fontName, "System")

        // Restore
        if let backup { try? backup.write(to: url) }
    }
}

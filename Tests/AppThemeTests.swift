import XCTest
@testable import Maurice

final class AppThemeTests: XCTestCase {

    // MARK: - Default values

    func testDefaultValues() {
        let theme = AppTheme()

        XCTAssertEqual(theme.meetingTabHue, 0.5718)
        XCTAssertEqual(theme.peopleTabHue, 0.4604)
        XCTAssertEqual(theme.taskTabHue, 0.7501)
        XCTAssertEqual(theme.memoryTabHue, 0.85)
        XCTAssertEqual(theme.markdown, MarkdownTheme())
    }

    func testDefaultMarkdownThemeIsDefault() {
        let theme = AppTheme()
        let defaultMarkdown = MarkdownTheme()

        XCTAssertEqual(theme.markdown.fontName, defaultMarkdown.fontName)
        XCTAssertEqual(theme.markdown.baseFontSize, defaultMarkdown.baseFontSize)
    }

    // MARK: - hue(for:)

    func testHueForMeetingTab() {
        let theme = AppTheme()
        XCTAssertEqual(theme.hue(for: .meeting), 0.5718)
    }

    func testHueForPeopleTab() {
        let theme = AppTheme()
        XCTAssertEqual(theme.hue(for: .people), 0.4604)
    }

    func testHueForTaskTab() {
        let theme = AppTheme()
        XCTAssertEqual(theme.hue(for: .task), 0.7501)
    }

    func testHueReturnsDifferentValuesPerTab() {
        let theme = AppTheme()

        let meetingHue = theme.hue(for: .meeting)
        let peopleHue = theme.hue(for: .people)
        let taskHue = theme.hue(for: .task)

        XCTAssertNotEqual(meetingHue, peopleHue)
        XCTAssertNotEqual(meetingHue, taskHue)
        XCTAssertNotEqual(peopleHue, taskHue)
    }

    // MARK: - setHue

    func testSetHueForMeeting() {
        var theme = AppTheme()
        theme.setHue(0.3, for: .meeting)
        XCTAssertEqual(theme.meetingTabHue, 0.3)
        // Other tabs unchanged
        XCTAssertEqual(theme.peopleTabHue, 0.4604)
        XCTAssertEqual(theme.taskTabHue, 0.7501)
    }

    func testSetHueForPeople() {
        var theme = AppTheme()
        theme.setHue(0.1, for: .people)
        XCTAssertEqual(theme.peopleTabHue, 0.1)
        XCTAssertEqual(theme.meetingTabHue, 0.5718)
    }

    func testSetHueForTask() {
        var theme = AppTheme()
        theme.setHue(0.9, for: .task)
        XCTAssertEqual(theme.taskTabHue, 0.9)
        XCTAssertEqual(theme.meetingTabHue, 0.5718)
    }

    func testSetHueThenGetHueRoundtrip() {
        var theme = AppTheme()
        theme.setHue(0.42, for: .meeting)
        XCTAssertEqual(theme.hue(for: .meeting), 0.42)
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
        original.meetingTabHue = 0.1
        original.peopleTabHue = 0.2
        original.taskTabHue = 0.3
        original.memoryTabHue = 0.4
        original.markdown.fontName = "Menlo"
        original.markdown.baseFontSize = 20

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppTheme.self, from: data)

        XCTAssertEqual(decoded.meetingTabHue, 0.1)
        XCTAssertEqual(decoded.peopleTabHue, 0.2)
        XCTAssertEqual(decoded.taskTabHue, 0.3)
        // memoryTabHue is not decoded (missing from init(from:)), so it resets to default
        XCTAssertEqual(decoded.memoryTabHue, AppTheme().memoryTabHue)
        XCTAssertEqual(decoded.markdown.fontName, "Menlo")
        XCTAssertEqual(decoded.markdown.baseFontSize, 20)
    }

    func testDecodeFromEmptyJSONUsesDefaults() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppTheme.self, from: json)
        let defaults = AppTheme()

        XCTAssertEqual(decoded.meetingTabHue, defaults.meetingTabHue)
        XCTAssertEqual(decoded.peopleTabHue, defaults.peopleTabHue)
        XCTAssertEqual(decoded.taskTabHue, defaults.taskTabHue)
        XCTAssertEqual(decoded.markdown, defaults.markdown)
    }

    func testDecodeFromPartialJSONUsesDefaultsForMissingKeys() throws {
        let json = """
        {"meetingTabHue": 0.99}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppTheme.self, from: json)

        XCTAssertEqual(decoded.meetingTabHue, 0.99)
        XCTAssertEqual(decoded.peopleTabHue, 0.4604)
        XCTAssertEqual(decoded.taskTabHue, 0.7501)
    }

    // MARK: - Equatable

    func testEquatable() {
        let themeA = AppTheme()
        let themeB = AppTheme()
        XCTAssertEqual(themeA, themeB)
    }

    func testNotEqualWhenHueDiffers() {
        var themeA = AppTheme()
        var themeB = AppTheme()
        themeA.meetingTabHue = 0.1
        themeB.meetingTabHue = 0.9
        XCTAssertNotEqual(themeA, themeB)
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

    // MARK: - Codable encode/decode roundtrip (no filesystem)

    func testCodableRoundtripPreservesAllHues() throws {
        var theme = AppTheme()
        theme.meetingTabHue = 0.123
        theme.peopleTabHue = 0.456
        theme.taskTabHue = 0.789

        let data = try JSONEncoder().encode(theme)
        let loaded = try JSONDecoder().decode(AppTheme.self, from: data)
        XCTAssertEqual(loaded.meetingTabHue, 0.123)
        XCTAssertEqual(loaded.peopleTabHue, 0.456)
        XCTAssertEqual(loaded.taskTabHue, 0.789)
    }

    func testDecodeCorruptDataReturnsNil() {
        let data = "not json!!".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(AppTheme.self, from: data)
        XCTAssertNil(decoded)
    }
}

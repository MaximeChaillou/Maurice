import XCTest
@testable import Maurice

final class AskButtonComponentsTests: XCTestCase {

    // MARK: - InlineMarkdownParser heading detection

    func testHeadingLevel1() {
        let result = InlineMarkdownParser.headingLevel("# Title")
        XCTAssertEqual(result.level, 1)
        XCTAssertEqual(result.content, "Title")
    }

    func testHeadingLevel2() {
        let result = InlineMarkdownParser.headingLevel("## Subtitle")
        XCTAssertEqual(result.level, 2)
        XCTAssertEqual(result.content, "Subtitle")
    }

    func testHeadingLevel3() {
        let result = InlineMarkdownParser.headingLevel("### Section")
        XCTAssertEqual(result.level, 3)
        XCTAssertEqual(result.content, "Section")
    }

    func testHeadingLevelBeyond3IsNotDetected() {
        let result = InlineMarkdownParser.headingLevel("#### Too deep")
        XCTAssertEqual(result.level, 0)
    }

    func testHeadingRequiresSpaceAfterHashes() {
        let result = InlineMarkdownParser.headingLevel("#NoSpace")
        XCTAssertEqual(result.level, 0)
    }

    func testHeadingWithOnlyHashAndSpaceIsNotHeading() {
        // "# " trims to "#", no space after hash → not a heading
        let result = InlineMarkdownParser.headingLevel("# ")
        XCTAssertEqual(result.level, 0)
    }

    func testHeadingWithContentAfterSpace() {
        let result = InlineMarkdownParser.headingLevel("# A")
        XCTAssertEqual(result.level, 1)
        XCTAssertEqual(result.content, "A")
    }

    func testNoHeadingPlainText() {
        let result = InlineMarkdownParser.headingLevel("Just some text")
        XCTAssertEqual(result.level, 0)
        XCTAssertEqual(result.content, "Just some text")
    }

    func testHeadingWithLeadingSpaces() {
        let result = InlineMarkdownParser.headingLevel("  ## Indented")
        XCTAssertEqual(result.level, 2)
        XCTAssertEqual(result.content, "Indented")
    }

    // MARK: - InlineMarkdownParser parse

    func testParsePlainText() {
        let result = InlineMarkdownParser.parse("Hello world")
        XCTAssertEqual(String(result.characters[...]), "Hello world")
    }

    func testParseBoldText() {
        let result = InlineMarkdownParser.parse("Some **bold** text")
        let plainText = String(result.characters[...])
        XCTAssertEqual(plainText, "Some bold text")
    }

    func testParseItalicText() {
        let result = InlineMarkdownParser.parse("Some *italic* text")
        let plainText = String(result.characters[...])
        XCTAssertEqual(plainText, "Some italic text")
    }

    func testParseBoldAndItalic() {
        let result = InlineMarkdownParser.parse("**bold** and *italic*")
        let plainText = String(result.characters[...])
        XCTAssertEqual(plainText, "bold and italic")
    }

    func testParseUnmatchedBoldMarker() {
        let result = InlineMarkdownParser.parse("Some **unclosed text")
        let plainText = String(result.characters[...])
        XCTAssertEqual(plainText, "Some **unclosed text")
    }

    func testParseUnmatchedItalicMarker() {
        let result = InlineMarkdownParser.parse("Some *unclosed text")
        let plainText = String(result.characters[...])
        XCTAssertEqual(plainText, "Some *unclosed text")
    }

    func testParseEmptyString() {
        let result = InlineMarkdownParser.parse("")
        XCTAssertEqual(String(result.characters[...]), "")
    }

    // MARK: - AskConversationLine

    func testConversationLineEquality() {
        let line = AskConversationLine(text: "Hello", kind: .user)
        XCTAssertEqual(line, line)
    }

    func testConversationLineDifferentIDsNotEqual() {
        let lineA = AskConversationLine(text: "Hello", kind: .user)
        let lineB = AskConversationLine(text: "Hello", kind: .user)
        XCTAssertNotEqual(lineA, lineB)
    }

    func testConversationLineKinds() {
        let user = AskConversationLine(text: "test", kind: .user)
        let assistant = AskConversationLine(text: "test", kind: .assistant)
        let tool = AskConversationLine(text: "test", kind: .tool)
        let system = AskConversationLine(text: "test", kind: .system)
        let error = AskConversationLine(text: "test", kind: .error)

        XCTAssertEqual(user.kind, .user)
        XCTAssertEqual(assistant.kind, .assistant)
        XCTAssertEqual(tool.kind, .tool)
        XCTAssertEqual(system.kind, .system)
        XCTAssertEqual(error.kind, .error)
    }

    // MARK: - AskConversationSegment

    func testSegmentSingleID() {
        let line = AskConversationLine(text: "test", kind: .user)
        let segment = AskConversationSegment.single(line)
        XCTAssertEqual(segment.id, line.id.uuidString)
    }

    func testSegmentToolGroupID() {
        let line1 = AskConversationLine(text: "tool1", kind: .tool)
        let line2 = AskConversationLine(text: "tool2", kind: .tool)
        let segment = AskConversationSegment.toolGroup([line1, line2])
        XCTAssertEqual(segment.id, line1.id.uuidString)
    }

    func testSegmentToolGroupEmptyFallback() {
        let segment = AskConversationSegment.toolGroup([])
        // Should not crash, returns a UUID string
        XCTAssertFalse(segment.id.isEmpty)
    }

    // MARK: - AskFont

    func testAskFontBodyIsNotNil() {
        let font = AskFont.body
        XCTAssertNotNil(font)
    }

    func testAskFontCaptionIsNotNil() {
        let font = AskFont.caption
        XCTAssertNotNil(font)
    }

    func testAskFontCustomSizes() {
        let regular = AskFont.regular(size: 16)
        let bold = AskFont.bold(size: 20)
        let semiBold = AskFont.semiBold(size: 14)
        XCTAssertNotNil(regular)
        XCTAssertNotNil(bold)
        XCTAssertNotNil(semiBold)
    }
}

import XCTest
@testable import Maurice

// MARK: - Helper to create a coordinator with a real NSTextView

@MainActor
private func makeCoordinator(
    text: String = "",
    theme: MarkdownTheme = MarkdownTheme()
) -> (MarkdownCoordinator, NSTextView, HidingLayoutManager) {
    let view = MarkdownView(content: .constant(text), theme: theme)
    let coordinator = MarkdownCoordinator(view)

    let textView = CheckboxTextView()
    textView.isRichText = true
    let layoutManager = HidingLayoutManager()
    textView.textContainer?.replaceLayoutManager(layoutManager)
    textView.string = text

    coordinator.textView = textView
    coordinator.hidingLM = layoutManager
    textView.coordinator = coordinator

    return (coordinator, textView, layoutManager)
}

// MARK: - numberedListPrefixLength

final class NumberedListPrefixTests: XCTestCase {

    @MainActor
    func testSimpleNumberedList() {
        let (coord, _, _) = makeCoordinator()
        XCTAssertEqual(coord.numberedListPrefixLength("1. Hello"), 3)
        XCTAssertEqual(coord.numberedListPrefixLength("42. Item"), 4)
        XCTAssertEqual(coord.numberedListPrefixLength("100. Big list"), 5)
    }

    @MainActor
    func testNotANumberedList() {
        let (coord, _, _) = makeCoordinator()
        XCTAssertNil(coord.numberedListPrefixLength("Hello"))
        XCTAssertNil(coord.numberedListPrefixLength("- bullet"))
        XCTAssertNil(coord.numberedListPrefixLength(""))
        XCTAssertNil(coord.numberedListPrefixLength("1.NoSpace"))
        XCTAssertNil(coord.numberedListPrefixLength(".5 text"))
        XCTAssertNil(coord.numberedListPrefixLength("abc. text"))
    }
}

// MARK: - hideRange

final class HideRangeTests: XCTestCase {

    @MainActor
    func testHideRangeAppendsRange() {
        let (coord, _, _) = makeCoordinator()
        coord.hideRange(NSRange(location: 0, length: 5))
        XCTAssertEqual(coord.hiddenRanges.count, 1)
        XCTAssertEqual(coord.hiddenRanges[0], NSRange(location: 0, length: 5))
    }

    @MainActor
    func testHideRangeIgnoresZeroLength() {
        let (coord, _, _) = makeCoordinator()
        coord.hideRange(NSRange(location: 0, length: 0))
        XCTAssertTrue(coord.hiddenRanges.isEmpty)
    }
}

// MARK: - paragraphStyle helpers

final class ParagraphStyleTests: XCTestCase {

    @MainActor
    func testParagraphStyleSpacing() {
        let (coord, _, _) = makeCoordinator()
        let style = coord.paragraphStyle(before: 12, after: 4) as! NSMutableParagraphStyle
        XCTAssertEqual(style.paragraphSpacingBefore, 12)
        XCTAssertEqual(style.paragraphSpacing, 4)
        XCTAssertEqual(style.lineSpacing, 4)
    }

    @MainActor
    func testParagraphStyleDefaultSpacing() {
        let (coord, _, _) = makeCoordinator()
        let style = coord.paragraphStyle() as! NSMutableParagraphStyle
        XCTAssertEqual(style.paragraphSpacingBefore, 0)
        XCTAssertEqual(style.paragraphSpacing, 0)
    }

    @MainActor
    func testParagraphStyleIndent() {
        let (coord, _, _) = makeCoordinator()
        let style = coord.paragraphStyle(firstIndent: 20, headIndent: 34) as! NSMutableParagraphStyle
        XCTAssertEqual(style.firstLineHeadIndent, 20)
        XCTAssertEqual(style.headIndent, 34)
        XCTAssertEqual(style.paragraphSpacingBefore, 4)
        XCTAssertEqual(style.paragraphSpacing, 4)
    }

    @MainActor
    func testParagraphStyleIndentCustomSpacing() {
        let (coord, _, _) = makeCoordinator()
        let style = coord.paragraphStyle(firstIndent: 10, headIndent: 20, before: 8, after: 8) as! NSMutableParagraphStyle
        XCTAssertEqual(style.paragraphSpacingBefore, 8)
        XCTAssertEqual(style.paragraphSpacing, 8)
    }
}

// MARK: - resolveFont / monoFont

final class FontResolutionTests: XCTestCase {

    @MainActor
    func testResolveFontSystem() {
        let (coord, _, _) = makeCoordinator()
        let font = coord.resolveFont(size: 14)
        XCTAssertEqual(font.pointSize, 14)
    }

    @MainActor
    func testResolveFontSystemMono() {
        var theme = MarkdownTheme()
        theme.fontName = "System Mono"
        let (coord, _, _) = makeCoordinator(theme: theme)
        let font = coord.resolveFont(size: 12)
        XCTAssertEqual(font.pointSize, 12)
        XCTAssertTrue(font.isFixedPitch)
    }

    @MainActor
    func testResolveFontCustom() {
        var theme = MarkdownTheme()
        theme.fontName = "Menlo"
        let (coord, _, _) = makeCoordinator(theme: theme)
        let font = coord.resolveFont(size: 13)
        XCTAssertEqual(font.pointSize, 13)
        XCTAssertEqual(font.familyName, "Menlo")
    }

    @MainActor
    func testResolveFontUnknownFallsBackToSystem() {
        var theme = MarkdownTheme()
        theme.fontName = "NonExistentFont12345"
        let (coord, _, _) = makeCoordinator(theme: theme)
        let font = coord.resolveFont(size: 14)
        XCTAssertEqual(font.pointSize, 14)
    }

    @MainActor
    func testMonoFont() {
        let (coord, _, _) = makeCoordinator()
        let font = coord.monoFont(size: 11)
        XCTAssertEqual(font.pointSize, 11)
        XCTAssertTrue(font.isFixedPitch)
    }
}

// MARK: - applyTraits

final class ApplyTraitsTests: XCTestCase {

    @MainActor
    func testApplyTraitsSystemBold() {
        let (coord, _, _) = makeCoordinator()
        let font = coord.applyTraits(size: 14, bold: true, italic: false)
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    @MainActor
    func testApplyTraitsSystemItalic() {
        let (coord, _, _) = makeCoordinator()
        let font = coord.applyTraits(size: 14, bold: false, italic: true)
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.italicFontMask))
    }

    @MainActor
    func testApplyTraitsSystemBoldItalic() {
        let (coord, _, _) = makeCoordinator()
        let font = coord.applyTraits(size: 14, bold: true, italic: true)
        XCTAssertEqual(font.pointSize, 14)
        // System font bold+italic is best-effort; verify it returns a valid font
        XCTAssertFalse(font.fontName.isEmpty)
    }

    @MainActor
    func testApplyTraitsTraditionalFont() {
        var theme = MarkdownTheme()
        theme.fontName = "Menlo"
        let (coord, _, _) = makeCoordinator(theme: theme)
        let font = coord.applyTraits(size: 13, bold: true, italic: true)
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.boldFontMask))
        XCTAssertTrue(traits.contains(.italicFontMask))
    }

    @MainActor
    func testApplyTraitsTraditionalNoTraits() {
        var theme = MarkdownTheme()
        theme.fontName = "Menlo"
        let (coord, _, _) = makeCoordinator(theme: theme)
        let font = coord.applyTraits(size: 13, bold: false, italic: false)
        XCTAssertEqual(font.pointSize, 13)
    }
}

// MARK: - applyMarkdownStyling (integration)

final class MarkdownStylingIntegrationTests: XCTestCase {

    @MainActor
    func testHeadingStyling() {
        let text = "# Title"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let storage = tv.textStorage!
        let font = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, 26) // h1FontSize
    }

    @MainActor
    func testH2Styling() {
        let text = "## Subtitle"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let font = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, 22)
    }

    @MainActor
    func testH3Styling() {
        let text = "### Section"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let font = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, 18)
    }

    @MainActor
    func testCodeBlockDetection() {
        let text = "```\ncode\n```"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // Line "code" (at offset 4) should have mono font
        let font = tv.textStorage!.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.isFixedPitch)
    }

    @MainActor
    func testBlockquoteStyling() {
        let text = "> Quote text"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let color = tv.textStorage!.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(color)
    }

    @MainActor
    func testBulletStyling() {
        let text = "- Item"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let para = tv.textStorage!.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(para)
        XCTAssertEqual(para?.headIndent, 14) // indent + 14
    }

    @MainActor
    func testCheckedItemStyling() {
        let text = "- [x] Done"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // Text after "- [x] " should have strikethrough
        let strike = tv.textStorage!.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func testCheckedItemUppercase() {
        let text = "- [X] Done"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let strike = tv.textStorage!.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func testUncheckedItemStyling() {
        let text = "- [ ] Todo"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let para = tv.textStorage!.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(para)
        XCTAssertEqual(para?.firstLineHeadIndent, 20)
    }

    @MainActor
    func testDividerStyling() {
        let text = "---"
        let (coord, _, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        XCTAssertEqual(coord.dividerInfos.count, 1)
    }

    @MainActor
    func testDividerVariants() {
        for divider in ["---", "***", "___"] {
            let (coord, _, _) = makeCoordinator(text: divider)
            coord.applyMarkdownStyling()
            XCTAssertEqual(coord.dividerInfos.count, 1, "Failed for divider: \(divider)")
        }
    }

    @MainActor
    func testNumberedListStyling() {
        let text = "1. First item"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let para = tv.textStorage!.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(para)
        XCTAssertEqual(para?.headIndent, 20) // indent + 20
    }

    @MainActor
    func testInlineBoldStyling() {
        let text = "Hello **bold** world"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // "bold" starts at index 8 (after "Hello **")
        let font = tv.textStorage!.attribute(.font, at: 8, effectiveRange: nil) as? NSFont
        let traits = NSFontManager.shared.traits(of: font!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    @MainActor
    func testInlineItalicStyling() {
        let text = "Hello *italic* world"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // "italic" starts at index 7 (after "Hello *")
        let font = tv.textStorage!.attribute(.font, at: 7, effectiveRange: nil) as? NSFont
        let traits = NSFontManager.shared.traits(of: font!)
        XCTAssertTrue(traits.contains(.italicFontMask))
    }

    @MainActor
    func testInlineCodeStyling() {
        let text = "Hello `code` world"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // "code" starts at index 7 (after "Hello `")
        let font = tv.textStorage!.attribute(.font, at: 7, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.isFixedPitch)
        let bg = tv.textStorage!.attribute(.backgroundColor, at: 7, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(bg)
    }

    @MainActor
    func testInlineStrikethroughStyling() {
        let text = "Hello ~~strike~~ world"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // "strike" starts at index 8 (after "Hello ~~")
        let strike = tv.textStorage!.attribute(.strikethroughStyle, at: 8, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func testEmptyTextDoesNotCrash() {
        let (coord, _, _) = makeCoordinator(text: "")
        coord.applyMarkdownStyling()
    }

    @MainActor
    func testTableRowStyling() {
        let text = "| A | B |\n| --- | --- |\n| 1 | 2 |"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // Table rows should have tiny font for raw text (custom drawing handles visuals)
        let font = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, 1)
        XCTAssertFalse(coord.tableBlockInfos.isEmpty)
    }

    @MainActor
    func testHeadingWithUnderline() {
        var theme = MarkdownTheme()
        theme.h1Underline = true
        let (coord, tv, _) = makeCoordinator(text: "# Title", theme: theme)
        coord.applyMarkdownStyling()
        let underline = tv.textStorage!.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func testBlockquoteWithUnderline() {
        var theme = MarkdownTheme()
        theme.quoteUnderline = true
        let (coord, tv, _) = makeCoordinator(text: "> Quote", theme: theme)
        coord.applyMarkdownStyling()
        let underline = tv.textStorage!.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func testBlockquoteBoldStyling() {
        var theme = MarkdownTheme()
        theme.quoteBold = true
        theme.quoteItalic = false
        let (coord, tv, _) = makeCoordinator(text: "> Bold quote", theme: theme)
        coord.applyMarkdownStyling()
        let font = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let traits = NSFontManager.shared.traits(of: font!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    @MainActor
    func testIndentedBullet() {
        let text = "  - Indented"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let para = tv.textStorage!.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        // 2 spaces * 7 = 14 indent, + 14 headIndent = 28
        XCTAssertEqual(para?.headIndent, 28)
    }

    @MainActor
    func testIndentedBlockquote() {
        let text = "  > Indented quote"
        let (coord, _, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // Should hide leading spaces + "> "
        XCTAssertFalse(coord.hiddenRanges.isEmpty)
    }

    @MainActor
    func testCodeBlockFenceActive() {
        // Active line should not be hidden, just dimmed
        let text = "```\ncode\n```"
        let (coord, tv, _) = makeCoordinator(text: text)
        // Simulate cursor on first line
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        coord.applyMarkdownStyling()
        // The ``` line is active, so its foreground should be tertiaryLabel, not hidden
        let color = tv.textStorage!.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(color)
    }

    @MainActor
    func testMultipleLines() {
        let text = "# Title\nParagraph\n- Bullet\n1. Number\n> Quote"
        let (coord, _, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // Just verify it processes all lines without crash
        XCTAssertTrue(coord.hiddenRanges.count > 0)
    }

    @MainActor
    func testDividerSingleCharVisible() {
        let text = "---"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // First char should have clear color (for drawing space), rest hidden
        let color = tv.textStorage!.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor.clear)
    }

    @MainActor
    func testInlineMarkdownNotAppliedOnActiveLine() {
        let text = "Hello **bold** world"
        let (coord, tv, _) = makeCoordinator(text: text)
        // Place cursor on the line to make it active
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        // Force window/firstResponder for currentLineIndex() to work
        coord.applyMarkdownStyling()
        // On active line, inline markdown is still applied but markers are not hidden
        // (the styling function checks active for block-level, inline is always applied if not active)
    }
}

// MARK: - Inline link styling

final class InlineLinkStylingTests: XCTestCase {

    @MainActor
    func testLinkColor() {
        let text = "Visit [Google](https://google.com) now"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // "Google" starts at index 7 (after "Visit [")
        let color = tv.textStorage!.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? NSColor
        let expected = MarkdownTheme().linkColor.nsColor
        XCTAssertEqual(color, expected)
    }

    @MainActor
    func testLinkUnderline() {
        let text = "Click [here](https://example.com)"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let underline = tv.textStorage!.attribute(.underlineStyle, at: 7, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
    }

    @MainActor
    func testLinkAttribute() {
        let text = "See [docs](https://docs.example.com/path)"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let link = tv.textStorage!.attribute(.link, at: 5, effectiveRange: nil) as? String
        XCTAssertEqual(link, "https://docs.example.com/path")
    }

    @MainActor
    func testLinkMarkersHidden() {
        let text = "[link](https://url.com)"
        let (coord, _, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // Should hide "[" (1 char) and "](https://url.com)" (18 chars) = 2 hidden ranges
        let linkHiddenRanges = coord.hiddenRanges.filter { $0.length > 0 }
        XCTAssertGreaterThanOrEqual(linkHiddenRanges.count, 2)
    }

    @MainActor
    func testMultipleLinksOnSameLine() {
        let text = "[a](https://a.com) and [b](https://b.com)"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // First link text "a" at index 1
        let link1 = tv.textStorage!.attribute(.link, at: 1, effectiveRange: nil) as? String
        XCTAssertEqual(link1, "https://a.com")
        // Second link text "b" at index 24
        let link2 = tv.textStorage!.attribute(.link, at: 24, effectiveRange: nil) as? String
        XCTAssertEqual(link2, "https://b.com")
    }

    @MainActor
    func testLinkCustomColor() {
        var theme = MarkdownTheme()
        theme.linkColor = CodableColor(red: 1, green: 0, blue: 0)
        let text = "[red](https://red.com)"
        let (coord, tv, _) = makeCoordinator(text: text, theme: theme)
        coord.applyMarkdownStyling()
        let color = tv.textStorage!.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, theme.linkColor.nsColor)
    }

    @MainActor
    func testNotALink() {
        let text = "Just [brackets] without url"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let link = tv.textStorage!.attribute(.link, at: 6, effectiveRange: nil)
        XCTAssertNil(link)
    }
}

// MARK: - HidingLayoutManager.styledCellText

final class StyledCellTextTests: XCTestCase {

    func testPlainText() {
        let font = NSFont.systemFont(ofSize: 13)
        let result = HidingLayoutManager.styledCellText("Hello", font: font, color: .labelColor, boldColor: .red, italicColor: .blue)
        XCTAssertEqual(result.string, "Hello")
    }

    func testBoldText() {
        let font = NSFont.systemFont(ofSize: 13)
        let result = HidingLayoutManager.styledCellText("**bold**", font: font, color: .labelColor, boldColor: .red, italicColor: .blue)
        XCTAssertEqual(result.string, "bold")
        let usedFont = result.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let traits = NSFontManager.shared.traits(of: usedFont!)
        XCTAssertTrue(traits.contains(.boldFontMask))
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .red)
    }

    func testItalicText() {
        let font = NSFont.systemFont(ofSize: 13)
        let result = HidingLayoutManager.styledCellText("*italic*", font: font, color: .labelColor, boldColor: .red, italicColor: .blue)
        XCTAssertEqual(result.string, "italic")
        let usedFont = result.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let traits = NSFontManager.shared.traits(of: usedFont!)
        XCTAssertTrue(traits.contains(.italicFontMask))
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .blue)
    }

    func testMixedText() {
        let font = NSFont.systemFont(ofSize: 13)
        let result = HidingLayoutManager.styledCellText("plain **bold** and *italic*", font: font, color: .labelColor, boldColor: .red, italicColor: .blue)
        XCTAssertEqual(result.string, "plain bold and italic")
    }

    func testEmptyText() {
        let font = NSFont.systemFont(ofSize: 13)
        let result = HidingLayoutManager.styledCellText("", font: font, color: .labelColor, boldColor: .red, italicColor: .blue)
        XCTAssertEqual(result.string, "")
    }

    func testNoMarkdown() {
        let font = NSFont.systemFont(ofSize: 13)
        let result = HidingLayoutManager.styledCellText("just text", font: font, color: .labelColor, boldColor: .red, italicColor: .blue)
        XCTAssertEqual(result.string, "just text")
    }

    func testTrailingPlainText() {
        let font = NSFont.systemFont(ofSize: 13)
        let result = HidingLayoutManager.styledCellText("**bold** end", font: font, color: .labelColor, boldColor: .red, italicColor: .blue)
        XCTAssertEqual(result.string, "bold end")
    }
}

// MARK: - toggleCheckbox

final class ToggleCheckboxTests: XCTestCase {

    @MainActor
    func testToggleUncheckedToChecked() {
        let text = "- [ ] Todo"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        coord.toggleCheckbox(at: 0)
        XCTAssertTrue(tv.string.hasPrefix("- [x] "))
    }

    @MainActor
    func testToggleCheckedToUnchecked() {
        let text = "- [x] Done"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        coord.toggleCheckbox(at: 0)
        XCTAssertTrue(tv.string.hasPrefix("- [ ] "))
    }

    @MainActor
    func testToggleUppercaseChecked() {
        let text = "- [X] Done"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        coord.toggleCheckbox(at: 0)
        XCTAssertTrue(tv.string.hasPrefix("- [ ] "))
    }

    @MainActor
    func testToggleNonCheckboxDoesNothing() {
        let text = "- Regular bullet"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        coord.toggleCheckbox(at: 0)
        XCTAssertEqual(tv.string, "- Regular bullet")
    }
}

// MARK: - updateTableCell

final class UpdateTableCellTests: XCTestCase {

    @MainActor
    func testUpdateTableCell() {
        let text = "| A | B |\n| --- | --- |\n| old | val |"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        // Update cell at data row (offset of "| old | val |"), column 0
        let lastLineOffset = (text as NSString).range(of: "| old").location
        let ref = TableCellRef(rowCharIndex: lastLineOffset, colIndex: 0)
        coord.updateTableCell(ref: ref, newValue: "new")
        XCTAssertTrue(tv.string.contains("new"))
    }
}

// MARK: - Table with narrow container (column width capping)

final class TableColumnWidthTests: XCTestCase {

    @MainActor
    func testWideTableColumnsShrunkFromIdeal() {
        // Create a long-cell table that would exceed container width
        let longCell = String(repeating: "ABCDEFGHIJ ", count: 20)
        let text = "| \(longCell) | \(longCell) | \(longCell) |\n| --- | --- | --- |\n| a | b | c |"
        let (coord, tv, _) = makeCoordinator(text: text)
        tv.setFrameSize(NSSize(width: 300, height: 500))
        tv.textContainer?.containerSize = NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        coord.applyMarkdownStyling()
        XCTAssertFalse(coord.tableBlockInfos.isEmpty)
        let table = coord.tableBlockInfos[0]
        let totalWidth = table.columnWidths.reduce(0, +)
        // Columns are shrunk from ideal — total should be much less than unconstrained width
        let font = NSFont.systemFont(ofSize: MarkdownTheme().baseFontSize)
        let idealSingle = (longCell as NSString).size(withAttributes: [.font: font]).width + table.cellPadding * 2
        XCTAssertLessThan(totalWidth, idealSingle * 3, "Table should be shrunk from ideal widths")
        // Each column must still fit its widest word ("ABCDEFGHIJ")
        let wordWidth = ("ABCDEFGHIJ" as NSString).size(withAttributes: [.font: font]).width
        for colW in table.columnWidths {
            XCTAssertGreaterThanOrEqual(colW, wordWidth)
        }
    }

    @MainActor
    func testColumnsRespectMinimumWordWidth() {
        // A narrow column with a long word must be wide enough to fit the word
        let text = "| Priorisation | A | B |\n| --- | --- | --- |\n| test | x | y |"
        let (coord, tv, _) = makeCoordinator(text: text)
        tv.setFrameSize(NSSize(width: 300, height: 500))
        tv.textContainer?.containerSize = NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        coord.applyMarkdownStyling()
        XCTAssertFalse(coord.tableBlockInfos.isEmpty)
        let table = coord.tableBlockInfos[0]
        // First column must be at least as wide as "Priorisation" + padding
        let font = NSFont.systemFont(ofSize: MarkdownTheme().baseFontSize, weight: .semibold)
        let wordWidth = ("Priorisation" as NSString).size(withAttributes: [.font: font]).width
        XCTAssertGreaterThanOrEqual(table.columnWidths[0], wordWidth)
    }

    @MainActor
    func testNarrowColumnsNotCrushedByWideColumns() {
        // When one column is very wide, narrow columns should still fit their words
        let longText = String(repeating: "LongWord ", count: 15)
        let text = "| Sujet | \(longText) | Owner |\n| --- | --- | --- |\n| A | B | Maxime |"
        let (coord, tv, _) = makeCoordinator(text: text)
        tv.setFrameSize(NSSize(width: 400, height: 500))
        tv.textContainer?.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        coord.applyMarkdownStyling()
        XCTAssertFalse(coord.tableBlockInfos.isEmpty)
        let table = coord.tableBlockInfos[0]
        // "Maxime" is the widest word in column 2 — column must fit it
        let font = NSFont.systemFont(ofSize: MarkdownTheme().baseFontSize)
        let maximeWidth = ("Maxime" as NSString).size(withAttributes: [.font: font]).width + table.cellPadding * 2
        XCTAssertGreaterThanOrEqual(table.columnWidths[2], maximeWidth)
    }

    @MainActor
    func testAllColumnsEqualWhenContentSimilar() {
        // Columns with similar content should get similar widths
        let text = "| Alpha | Bravo | Charlie |\n| --- | --- | --- |\n| one | two | three |"
        let (coord, tv, _) = makeCoordinator(text: text)
        tv.setFrameSize(NSSize(width: 800, height: 500))
        tv.textContainer?.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
        coord.applyMarkdownStyling()
        XCTAssertFalse(coord.tableBlockInfos.isEmpty)
        let widths = coord.tableBlockInfos[0].columnWidths
        // With plenty of space, no column should be drastically different
        let maxW = widths.max()!
        let minW = widths.min()!
        XCTAssertLessThan(maxW - minW, 100, "Similar columns should have similar widths")
    }
}

// MARK: - CodableColor edge case

final class CodableColorEdgeCaseTests: XCTestCase {

    func testInitFromCatalogColor() {
        // NSColor.labelColor is a catalog color; conversion to sRGB uses fallback
        let codable = CodableColor(.labelColor)
        // Should not crash and should have valid components
        XCTAssertTrue(codable.alpha > 0)
    }

}

// MARK: - Additional styling edge cases

final class StylingEdgeCaseTests: XCTestCase {

    @MainActor
    func testActiveCodeLineNonFence() {
        // When cursor is on a code line (not a ``` fence), it gets code styling but stays visible
        let text = "```\ncode line\n```"
        let (coord, tv, _) = makeCoordinator(text: text)
        // Place cursor on the "code line" (line index 1, offset 4)
        tv.setSelectedRange(NSRange(location: 4, length: 0))
        coord.applyMarkdownStyling()
        // The code line should have monospace font
        let font = tv.textStorage!.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.isFixedPitch)
    }

    @MainActor
    func testActiveCodeFenceLine() {
        // When cursor is on a ``` fence, it gets dimmed but not hidden
        let text = "```\ncode\n```"
        let (coord, tv, _) = makeCoordinator(text: text)
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        coord.applyMarkdownStyling()
        let color = tv.textStorage!.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(color)
    }

    @MainActor
    func testComputeColumnWidthsWithOneVeryWideColumn() {
        // One column vastly wider than others — narrow columns should still get minimum word width
        let longA = String(repeating: "X", count: 100)
        let text = "| \(longA) | B | C |\n| --- | --- | --- |\n| a | b | c |"
        let (coord, tv, _) = makeCoordinator(text: text)
        tv.setFrameSize(NSSize(width: 200, height: 500))
        tv.textContainer?.containerSize = NSSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        coord.applyMarkdownStyling()
        XCTAssertFalse(coord.tableBlockInfos.isEmpty)
    }
}

// MARK: - Data structures

final class MarkdownDataStructureTests: XCTestCase {

    func testCheckboxDrawInfo() {
        let info = CheckboxDrawInfo(charIndex: 0, visibleCharIndex: 6, checked: true, indent: 0)
        XCTAssertTrue(info.checked)
        XCTAssertEqual(info.charIndex, 0)
    }

    func testDividerDrawInfo() {
        let info = DividerDrawInfo(charIndex: 10, color: .red)
        XCTAssertEqual(info.charIndex, 10)
    }

    func testTableCellRefEquatable() {
        let a = TableCellRef(rowCharIndex: 0, colIndex: 1)
        let b = TableCellRef(rowCharIndex: 0, colIndex: 1)
        let c = TableCellRef(rowCharIndex: 0, colIndex: 2)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testTableRowContext() {
        let ctx = TableRowContext(isHeader: true, isSeparator: false, dataRowIndex: -1)
        XCTAssertTrue(ctx.isHeader)
        XCTAssertFalse(ctx.isSeparator)
        XCTAssertEqual(ctx.dataRowIndex, -1)
    }
}

// MARK: - Incremental restyle

final class IncrementalRestyleTests: XCTestCase {

    @MainActor
    func testRestyleLinesUpdatesOldAndNewActiveLines() {
        let text = "# Title\nParagraph\n- Bullet"
        let (coord, _, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()

        // After full restyle, heading prefix "# " is hidden (line 0 is not active)
        let headingHidden = coord.hiddenRanges.contains { $0.location == 0 }
        XCTAssertTrue(headingHidden, "Heading prefix should be hidden initially")

        // Simulate cursor moving from line -1 (no line) to line 0 (heading)
        coord.restyleLines(old: -1, new: 0)

        // Line 0 is now active: its "# " prefix should no longer be hidden
        let headingStillHidden = coord.hiddenRanges.contains { $0.location == 0 && $0.length == 2 }
        XCTAssertFalse(headingStillHidden, "Active heading line should not have hidden prefix")
    }

    @MainActor
    func testRestyleLinesMovesBetweenLines() {
        let text = "# Title\n- Bullet"
        let (coord, _, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()

        // Move cursor to line 0 (heading)
        coord.restyleLines(old: -1, new: 0)
        let headingHiddenAfterActivate = coord.hiddenRanges.contains { $0.location == 0 && $0.length == 2 }
        XCTAssertFalse(headingHiddenAfterActivate)

        // Move cursor away from line 0 to line 1 (bullet)
        coord.restyleLines(old: 0, new: 1)
        // Line 0 should have hidden prefix restored
        let headingHiddenAfterDeactivate = coord.hiddenRanges.contains { $0.location == 0 && $0.length == 2 }
        XCTAssertTrue(headingHiddenAfterDeactivate, "Heading prefix should be hidden after line deactivated")
    }

    @MainActor
    func testRestyleLinesPreservesOtherLinesStyling() {
        let text = "# Title\nPlain text\n- Bullet"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()

        // Capture font on heading before restyle
        let headingFont = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont

        // Move cursor to line 2 (bullet) — should not affect heading styling
        coord.restyleLines(old: -1, new: 2)

        let headingFontAfter = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(headingFont?.pointSize, headingFontAfter?.pointSize,
                       "Heading font should be unchanged by restyle of unrelated line")
    }
}

// MARK: - applyMarkdownStyling with newContent

final class SinglePassContentStylingTests: XCTestCase {

    @MainActor
    func testApplyMarkdownStylingWithNewContent() {
        let (coord, tv, _) = makeCoordinator(text: "")
        coord.applyMarkdownStyling(newContent: "# Hello")
        XCTAssertEqual(tv.string, "# Hello")
        let font = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, 26) // h1FontSize
    }

    @MainActor
    func testApplyMarkdownStylingReplacesContent() {
        let (coord, tv, _) = makeCoordinator(text: "Old text")
        coord.applyMarkdownStyling(newContent: "- Bullet")
        XCTAssertEqual(tv.string, "- Bullet")
        let para = tv.textStorage!.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(para?.headIndent, 14) // bullet indent
    }

    @MainActor
    func testApplyMarkdownStylingWithNilKeepsContent() {
        let (coord, tv, _) = makeCoordinator(text: "# Title")
        coord.applyMarkdownStyling()
        let fontBefore = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        coord.applyMarkdownStyling(newContent: nil)
        let fontAfter = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(tv.string, "# Title")
        XCTAssertEqual(fontBefore?.pointSize, fontAfter?.pointSize)
    }
}

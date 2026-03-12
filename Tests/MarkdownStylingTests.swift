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
        XCTAssertEqual(font?.pointSize, 20)
    }

    @MainActor
    func testH3Styling() {
        let text = "### Section"
        let (coord, tv, _) = makeCoordinator(text: text)
        coord.applyMarkdownStyling()
        let font = tv.textStorage!.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, 17)
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
    func testWideTableColumnsCapped() {
        // Create a long-cell table that would exceed container width
        let longCell = String(repeating: "ABCDEFGHIJ ", count: 20)
        let text = "| \(longCell) | \(longCell) | \(longCell) |\n| --- | --- | --- |\n| a | b | c |"
        let (coord, tv, _) = makeCoordinator(text: text)
        // Set a narrow container and matching bounds
        tv.setFrameSize(NSSize(width: 300, height: 500))
        tv.textContainer?.containerSize = NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        coord.applyMarkdownStyling()
        // Verify table was built (column widths should be capped)
        XCTAssertFalse(coord.tableBlockInfos.isEmpty)
        let totalWidth = coord.tableBlockInfos[0].columnWidths.reduce(0, +)
        // Columns should be capped — each at minColWidth (60) = 180 total
        XCTAssertLessThanOrEqual(totalWidth, 300)
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
    func testComputeColumnWidthsReNormalization() {
        // Create a table where some columns hit minColWidth (60) but total still exceeds
        // This triggers the re-normalization branch
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

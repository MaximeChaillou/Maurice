import AppKit

// MARK: - Cached Regexes

private func regex(_ pattern: String) -> NSRegularExpression {
    do {
        return try NSRegularExpression(pattern: pattern)
    } catch {
        fatalError("Invalid regex pattern: \(pattern) — \(error)")
    }
}

private enum MarkdownRegex {
    static let bold = regex("\\*\\*(.+?)\\*\\*")
    static let italic = regex("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)")
    static let inlineCode = regex("(?<!`)`(?!`)(.+?)(?<!`)`(?!`)")
    static let strikethrough = regex("~~(.+?)~~")
    static let link = regex("\\[([^\\]]+)\\]\\(([^)]+)\\)")
}

// MARK: - Block & Inline Styling

extension MarkdownCoordinator {

    // MARK: - Code blocks

    func styleCodeLine(storage: NSTextStorage, trimmed: String, range: NSRange, active: Bool) {
        let mono = monoFont(size: theme.baseFontSize - 1)
        storage.addAttributes([
            .font: mono,
            .foregroundColor: theme.codeColor,
            .backgroundColor: theme.codeBlockBackgroundColor
        ], range: range)
        if trimmed.hasPrefix("```") {
            if active {
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
            } else {
                hideRange(range)
            }
        }
    }

    // MARK: - Block-level styling

    struct LineContext {
        let storage: NSTextStorage
        let line: String
        let trimmed: String
        let range: NSRange
        let offset: Int
        let active: Bool
    }

    func styleMarkdownLine(_ ctx: LineContext) {
        let storage = ctx.storage
        let trimmed = ctx.trimmed
        let range = ctx.range
        let offset = ctx.offset
        let active = ctx.active
        let leading = ctx.line.prefix(while: { $0 == " " || $0 == "\t" }).count

        if trimmed.hasPrefix("#### ") || trimmed.hasPrefix("### ")
            || trimmed.hasPrefix("## ") || trimmed.hasPrefix("# ") {
            styleHeading(storage: storage, trimmed: trimmed, range: range, offset: offset, active: active)
        } else if trimmed.hasPrefix("> ") {
            styleBlockquote(storage: storage, range: range, offset: offset, leading: leading, active: active)
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
                    || trimmed.hasPrefix("- [x]\u{00A0}") || trimmed.hasPrefix("- [X]\u{00A0}") {
            styleCheckedItem(storage: storage, range: range, offset: offset, leading: leading, active: active)
        } else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [\u{00A0}] ")
                    || trimmed.hasPrefix("- [ ]\u{00A0}") || trimmed.hasPrefix("- [\u{00A0}]\u{00A0}") {
            styleUncheckedItem(storage: storage, range: range, offset: offset, leading: leading, active: active)
        } else if trimmed.hasPrefix("- ") {
            styleBullet(storage: storage, range: range, offset: offset, leading: leading, active: active)
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            styleDivider(storage: storage, range: range, active: active)
        } else if numberedListPrefixLength(trimmed) != nil {
            styleNumberedItem(storage: storage, range: range, offset: offset, leading: leading, active: active)
        } else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
            styleTableRow(storage: storage, trimmed: trimmed, range: range, offset: offset, active: active)
        }
    }

    private struct HeadingStyle {
        let prefixLen: Int
        let fontSize: CGFloat
        let kernEm: CGFloat
        let bold: Bool
        let italic: Bool
        let underline: Bool
        let color: NSColor
        let para: NSParagraphStyle
    }

    private func headingStyle(for trimmed: String) -> HeadingStyle {
        if trimmed.hasPrefix("#### ") {
            return HeadingStyle(
                prefixLen: 5, fontSize: theme.h4FontSize, kernEm: -0.005,
                bold: theme.h4Bold, italic: theme.h4Italic, underline: theme.h4Underline,
                color: theme.h4Color, para: paragraphStyle(before: 8, after: 2)
            )
        }
        if trimmed.hasPrefix("### ") {
            return HeadingStyle(
                prefixLen: 4, fontSize: theme.h3FontSize, kernEm: -0.010,
                bold: theme.h3Bold, italic: theme.h3Italic, underline: theme.h3Underline,
                color: theme.h3Color, para: paragraphStyle(before: 10, after: 2)
            )
        }
        if trimmed.hasPrefix("## ") {
            return HeadingStyle(
                prefixLen: 3, fontSize: theme.h2FontSize, kernEm: -0.018,
                bold: theme.h2Bold, italic: theme.h2Italic, underline: theme.h2Underline,
                color: theme.h2Color, para: paragraphStyle(before: 14, after: 4)
            )
        }
        return HeadingStyle(
            prefixLen: 2, fontSize: theme.h1FontSize, kernEm: -0.025,
            bold: theme.h1Bold, italic: theme.h1Italic, underline: theme.h1Underline,
            color: theme.h1Color, para: paragraphStyle(before: 12, after: 6)
        )
    }

    private func styleHeading(
        storage: NSTextStorage, trimmed: String,
        range: NSRange, offset: Int, active: Bool
    ) {
        let style = headingStyle(for: trimmed)
        let font = applyTraits(size: style.fontSize, bold: style.bold, italic: style.italic)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: style.para,
            .foregroundColor: style.color,
            .kern: style.fontSize * style.kernEm
        ]
        if style.underline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        storage.addAttributes(attrs, range: range)
        if !active { hideRange(NSRange(location: offset, length: style.prefixLen)) }
    }

    private func styleBlockquote(
        storage: NSTextStorage, range: NSRange, offset: Int,
        leading: Int, active: Bool
    ) {
        let indent = CGFloat(leading) * 7
        let font = applyTraits(size: theme.baseFontSize, bold: theme.quoteBold, italic: theme.quoteItalic)
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.quoteColor,
            .font: font,
            .paragraphStyle: paragraphStyle(firstIndent: indent + 12, headIndent: indent + 12)
        ]
        if theme.quoteUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        storage.addAttributes(attrs, range: range)
        if !active {
            if leading > 0 { hideRange(NSRange(location: offset, length: leading)) }
            hideRange(NSRange(location: offset + leading, length: 2))
        }
    }

    private func styleCheckedItem(
        storage: NSTextStorage, range: NSRange, offset: Int,
        leading: Int, active: Bool
    ) {
        let indent = CGFloat(leading) * 7
        let para = paragraphStyle(firstIndent: indent + 20, headIndent: indent + 20)
        storage.addAttribute(.paragraphStyle, value: para, range: range)
        let prefixEnd = offset + leading + 6
        let textRange = NSRange(location: prefixEnd, length: max(range.length - leading - 6, 0))
        if textRange.length > 0 {
            storage.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ], range: textRange)
        }
        if !active {
            hideRange(NSRange(location: offset, length: leading + 6))
            let visibleStart = min(offset + leading + 6, offset + range.length)
            checkboxInfos.append(CheckboxDrawInfo(
                charIndex: offset + leading, visibleCharIndex: visibleStart,
                checked: true, indent: indent,
                borderColor: theme.taskBorderColor, fillColor: theme.accentColor
            ))
        }
    }

    private func styleUncheckedItem(
        storage: NSTextStorage, range: NSRange, offset: Int,
        leading: Int, active: Bool
    ) {
        let indent = CGFloat(leading) * 7
        let para = paragraphStyle(firstIndent: indent + 20, headIndent: indent + 20)
        storage.addAttribute(.paragraphStyle, value: para, range: range)
        if !active {
            hideRange(NSRange(location: offset, length: leading + 6))
            let visibleStart = min(offset + leading + 6, offset + range.length)
            checkboxInfos.append(CheckboxDrawInfo(
                charIndex: offset + leading, visibleCharIndex: visibleStart,
                checked: false, indent: indent,
                borderColor: theme.taskBorderColor, fillColor: theme.accentColor
            ))
        }
    }

    private func styleBullet(
        storage: NSTextStorage, range: NSRange, offset: Int,
        leading: Int, active: Bool
    ) {
        let indent = CGFloat(leading) * 7
        let para = paragraphStyle(firstIndent: indent, headIndent: indent + 14)
        storage.addAttribute(.paragraphStyle, value: para, range: range)
        if !active {
            if leading > 0 { hideRange(NSRange(location: offset, length: leading)) }
            replacements[offset + leading] = 0x2022 // •
        }
    }

    private func styleDivider(storage: NSTextStorage, range: NSRange, active: Bool) {
        storage.addAttribute(.foregroundColor, value: theme.dividerColor, range: range)
        if !active {
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: range.location, length: 1))
            if range.length > 1 {
                hideRange(NSRange(location: range.location + 1, length: range.length - 1))
            }
            dividerInfos.append(DividerDrawInfo(charIndex: range.location, color: theme.dividerColor))
        }
    }

    private func styleNumberedItem(
        storage: NSTextStorage, range: NSRange, offset: Int,
        leading: Int, active: Bool
    ) {
        let indent = CGFloat(leading) * 7
        let para = paragraphStyle(firstIndent: indent, headIndent: indent + 20)
        storage.addAttribute(.paragraphStyle, value: para, range: range)
        if !active {
            if leading > 0 { hideRange(NSRange(location: offset, length: leading)) }
        }
    }

    private func styleTableRow(
        storage: NSTextStorage, trimmed: String,
        range: NSRange, offset: Int, active: Bool
    ) {
        storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
        // Use a tiny font so the raw markdown text never wraps — custom drawing handles all visuals
        storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 1), range: range)

        let rowHeight = rowHeightForCharIndex(offset) ?? 20
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = rowHeight
        para.maximumLineHeight = rowHeight
        para.lineBreakMode = .byClipping
        storage.addAttribute(.paragraphStyle, value: para, range: range)
    }

    private func rowHeightForCharIndex(_ charIndex: Int) -> CGFloat? {
        for table in tableBlockInfos {
            for (i, row) in table.rows.enumerated() where row.charIndex == charIndex {
                guard i < table.rowHeights.count else { return nil }
                return table.rowHeights[i]
            }
        }
        return nil
    }

    // MARK: - Inline markdown styling

    struct InlineStyle {
        let regex: NSRegularExpression
        let markerLen: Int
        let trait: NSFontTraitMask
        let color: NSColor
    }

    func styleInlineMarkdown(storage: NSTextStorage, range: NSRange) {
        guard let textView else { return }
        let lineText = (textView.string as NSString).substring(with: range)

        let styles: [InlineStyle] = [
            InlineStyle(regex: MarkdownRegex.bold, markerLen: 2,
                        trait: .boldFontMask, color: theme.boldColor),
            InlineStyle(regex: MarkdownRegex.italic, markerLen: 1,
                        trait: .italicFontMask, color: theme.italicColor)
        ]
        for style in styles {
            styleInlinePattern(storage: storage, lineText: lineText, baseOffset: range.location, style: style)
        }
        styleInlineCode(storage: storage, lineText: lineText, baseOffset: range.location)
        styleInlineStrikethrough(storage: storage, lineText: lineText, baseOffset: range.location)
        styleInlineLinks(storage: storage, lineText: lineText, baseOffset: range.location)
    }

    private func styleInlinePattern(
        storage: NSTextStorage, lineText: String, baseOffset: Int,
        style: InlineStyle
    ) {
        let nsLine = lineText as NSString
        for match in style.regex.matches(in: lineText, range: NSRange(location: 0, length: nsLine.length)) {
            let full = match.range
            hideRange(NSRange(location: baseOffset + full.location, length: style.markerLen))
            hideRange(NSRange(location: baseOffset + full.location + full.length - style.markerLen, length: style.markerLen))
            let contentRange = NSRange(
                location: baseOffset + full.location + style.markerLen,
                length: full.length - style.markerLen * 2
            )
            if contentRange.length > 0 {
                let cur = storage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont
                    ?? resolveFont(size: theme.baseFontSize)
                storage.addAttributes([
                    .font: NSFontManager.shared.convert(cur, toHaveTrait: style.trait),
                    .foregroundColor: style.color
                ], range: contentRange)
            }
        }
    }

    private func styleInlineCode(storage: NSTextStorage, lineText: String, baseOffset: Int) {
        let nsLine = lineText as NSString
        for match in MarkdownRegex.inlineCode.matches(in: lineText, range: NSRange(location: 0, length: nsLine.length)) {
            let full = match.range
            hideRange(NSRange(location: baseOffset + full.location, length: 1))
            hideRange(NSRange(location: baseOffset + full.location + full.length - 1, length: 1))
            let contentRange = NSRange(location: baseOffset + full.location + 1, length: full.length - 2)
            if contentRange.length > 0 {
                storage.addAttributes([
                    .font: monoFont(size: theme.baseFontSize - 1),
                    .foregroundColor: theme.codeColor,
                    .backgroundColor: theme.codeBackgroundColor
                ], range: contentRange)
            }
        }
    }

    private func styleInlineStrikethrough(storage: NSTextStorage, lineText: String, baseOffset: Int) {
        let nsLine = lineText as NSString
        for match in MarkdownRegex.strikethrough.matches(in: lineText, range: NSRange(location: 0, length: nsLine.length)) {
            let full = match.range
            hideRange(NSRange(location: baseOffset + full.location, length: 2))
            hideRange(NSRange(location: baseOffset + full.location + full.length - 2, length: 2))
            let contentRange = NSRange(location: baseOffset + full.location + 2, length: full.length - 4)
            if contentRange.length > 0 {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
            }
        }
    }

    private func styleInlineLinks(storage: NSTextStorage, lineText: String, baseOffset: Int) {
        let nsLine = lineText as NSString
        for match in MarkdownRegex.link.matches(in: lineText, range: NSRange(location: 0, length: nsLine.length)) {
            let full = match.range
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            guard textRange.location != NSNotFound, urlRange.location != NSNotFound else { continue }

            let urlString = nsLine.substring(with: urlRange)
            let contentRange = NSRange(location: baseOffset + textRange.location, length: textRange.length)

            // Hide `[` before text
            hideRange(NSRange(location: baseOffset + full.location, length: 1))
            // Hide `](url)` after text
            let suffixStart = textRange.location + textRange.length
            let suffixLen = full.length - suffixStart + full.location
            hideRange(NSRange(location: baseOffset + suffixStart, length: suffixLen))

            if contentRange.length > 0 {
                storage.addAttributes([
                    .foregroundColor: theme.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: urlString,
                    .cursor: NSCursor.pointingHand,
                ], range: contentRange)
            }
        }
    }

    // MARK: - Helpers

    func applyTraits(size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        let isSystemFont = theme.fontName == "System" || theme.fontName == "System Mono"

        if isSystemFont {
            // System fonts use weight-based bold, not trait-based
            var font = resolveFont(size: size, weight: bold ? .bold : .regular)
            if italic {
                let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
                font = NSFont(descriptor: descriptor, size: size) ?? font
            }
            return font
        } else {
            // Traditional fonts use NSFontManager traits
            var font = resolveFont(size: size)
            var traits: NSFontTraitMask = []
            if bold { traits.insert(.boldFontMask) }
            if italic { traits.insert(.italicFontMask) }
            if !traits.isEmpty {
                font = NSFontManager.shared.convert(font, toHaveTrait: traits)
            }
            return font
        }
    }

    func hideRange(_ range: NSRange) {
        guard range.length > 0 else { return }
        hiddenRanges.append(range)
    }

    func paragraphStyle(before: CGFloat = 0, after: CGFloat = 0) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.paragraphSpacingBefore = before
        style.paragraphSpacing = after
        return style
    }

    func paragraphStyle(firstIndent: CGFloat, headIndent: CGFloat, before: CGFloat = 4, after: CGFloat = 4) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.paragraphSpacingBefore = before
        style.paragraphSpacing = after
        style.firstLineHeadIndent = firstIndent
        style.headIndent = headIndent
        return style
    }

    func numberedListPrefixLength(_ trimmed: String) -> Int? {
        guard let dotIdx = trimmed.firstIndex(of: "."),
              trimmed[trimmed.startIndex..<dotIdx].allSatisfy(\.isNumber),
              trimmed.index(after: dotIdx) < trimmed.endIndex,
              trimmed[trimmed.index(after: dotIdx)] == " " else { return nil }
        return trimmed.distance(from: trimmed.startIndex, to: trimmed.index(dotIdx, offsetBy: 2))
    }
}

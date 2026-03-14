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
}

// MARK: - Block & Inline Styling

extension MarkdownCoordinator {

    // MARK: - Code blocks

    func styleCodeLine(storage: NSTextStorage, trimmed: String, range: NSRange, active: Bool) {
        let mono = monoFont(size: theme.baseFontSize - 1)
        storage.addAttributes([.font: mono, .foregroundColor: theme.codeColor.nsColor], range: range)
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

        if trimmed.hasPrefix("### ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("# ") {
            styleHeading(storage: storage, trimmed: trimmed, range: range, offset: offset, active: active)
        } else if trimmed.hasPrefix("> ") {
            styleBlockquote(storage: storage, range: range, offset: offset, leading: leading, active: active)
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            styleCheckedItem(storage: storage, range: range, offset: offset, leading: leading, active: active)
        } else if trimmed.hasPrefix("- [ ] ") {
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

    private func styleHeading(
        storage: NSTextStorage, trimmed: String,
        range: NSRange, offset: Int, active: Bool
    ) {
        let level: Int
        let prefixLen: Int
        if trimmed.hasPrefix("### ") {
            level = 3; prefixLen = 4
        } else if trimmed.hasPrefix("## ") {
            level = 2; prefixLen = 3
        } else {
            level = 1; prefixLen = 2
        }

        let para: NSParagraphStyle
        let color: NSColor
        let isBold: Bool
        let isItalic: Bool
        let isUnderline: Bool
        let fontSize: CGFloat
        switch level {
        case 1:
            fontSize = theme.h1FontSize
            para = paragraphStyle(before: 12, after: 4)
            color = theme.h1Color.nsColor
            isBold = theme.h1Bold; isItalic = theme.h1Italic; isUnderline = theme.h1Underline
        case 2:
            fontSize = theme.h2FontSize
            para = paragraphStyle(before: 12, after: 2)
            color = theme.h2Color.nsColor
            isBold = theme.h2Bold; isItalic = theme.h2Italic; isUnderline = theme.h2Underline
        default:
            fontSize = theme.h3FontSize
            para = paragraphStyle(before: 8, after: 2)
            color = theme.h3Color.nsColor
            isBold = theme.h3Bold; isItalic = theme.h3Italic; isUnderline = theme.h3Underline
        }
        let font = applyTraits(size: fontSize, bold: isBold, italic: isItalic)
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: para, .foregroundColor: color]
        if isUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        storage.addAttributes(attrs, range: range)
        if !active { hideRange(NSRange(location: offset, length: prefixLen)) }
    }

    private func styleBlockquote(
        storage: NSTextStorage, range: NSRange, offset: Int,
        leading: Int, active: Bool
    ) {
        let indent = CGFloat(leading) * 7
        let font = applyTraits(size: theme.baseFontSize, bold: theme.quoteBold, italic: theme.quoteItalic)
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.quoteColor.nsColor,
            .font: font,
            .paragraphStyle: paragraphStyle(firstIndent: indent, headIndent: indent + 14)
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
                checked: true, indent: indent
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
                checked: false, indent: indent
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
        storage.addAttribute(.foregroundColor, value: theme.dividerColor.nsColor, range: range)
        if !active {
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: range.location, length: 1))
            if range.length > 1 {
                hideRange(NSRange(location: range.location + 1, length: range.length - 1))
            }
            dividerInfos.append(DividerDrawInfo(charIndex: range.location, color: theme.dividerColor.nsColor))
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
                        trait: .boldFontMask, color: theme.boldColor.nsColor),
            InlineStyle(regex: MarkdownRegex.italic, markerLen: 1,
                        trait: .italicFontMask, color: theme.italicColor.nsColor)
        ]
        for style in styles {
            styleInlinePattern(storage: storage, lineText: lineText, baseOffset: range.location, style: style)
        }
        styleInlineCode(storage: storage, lineText: lineText, baseOffset: range.location)
        styleInlineStrikethrough(storage: storage, lineText: lineText, baseOffset: range.location)
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
                    .foregroundColor: theme.codeColor.nsColor,
                    .backgroundColor: theme.codeBackgroundColor.nsColor
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

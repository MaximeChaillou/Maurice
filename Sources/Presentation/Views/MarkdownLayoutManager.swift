import AppKit

// MARK: - CheckboxDrawInfo

struct CheckboxDrawInfo {
    let charIndex: Int
    let visibleCharIndex: Int
    let checked: Bool
    let indent: CGFloat
}

struct DividerDrawInfo {
    let charIndex: Int
    let color: NSColor
}

// MARK: - TableBlockDrawInfo

struct TableBlockDrawInfo {
    struct Row {
        let charIndex: Int
        let cells: [String]
        let isHeader: Bool
        let isSeparator: Bool
        let dataRowIndex: Int
    }
    let rows: [Row]
    let columnWidths: [CGFloat]
    let rowHeights: [CGFloat]
    let cellPadding: CGFloat
    let font: NSFont
    let headerFont: NSFont
    let textColor: NSColor
    let boldColor: NSColor
    let italicColor: NSColor
    let headerBgColor: NSColor
    let stripeBgColor: NSColor
    let borderColor: NSColor
}

struct TableCellRef: Equatable {
    let rowCharIndex: Int
    let colIndex: Int
}

// MARK: - HidingLayoutManager

class HidingLayoutManager: NSLayoutManager {
    var hiddenCharIndexes = IndexSet()
    var glyphReplacements: [Int: UniChar] = [:]
    var checkboxes: [CheckboxDrawInfo] = []
    var dividers: [DividerDrawInfo] = []
    var tableBlocks: [TableBlockDrawInfo] = []
    var activeTableCell: TableCellRef?

    override func setGlyphs(
        _ glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font aFont: NSFont,
        forGlyphRange glyphRange: NSRange
    ) {
        let count = glyphRange.length
        let newGlyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: count)
        let newProps = UnsafeMutablePointer<NSLayoutManager.GlyphProperty>.allocate(capacity: count)
        defer { newGlyphs.deallocate(); newProps.deallocate() }

        for idx in 0..<count {
            let charIdx = charIndexes[idx]
            if hiddenCharIndexes.contains(charIdx) {
                newGlyphs[idx] = glyphs[idx]
                newProps[idx] = .null
            } else if var replacement = glyphReplacements[charIdx] {
                var glyph: CGGlyph = 0
                CTFontGetGlyphsForCharacters(aFont as CTFont, &replacement, &glyph, 1)
                newGlyphs[idx] = glyph
                newProps[idx] = props[idx]
            } else {
                newGlyphs[idx] = glyphs[idx]
                newProps[idx] = props[idx]
            }
        }

        super.setGlyphs(
            newGlyphs, properties: newProps,
            characterIndexes: charIndexes, font: aFont,
            forGlyphRange: glyphRange
        )
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        drawDividers(glyphsToShow: glyphsToShow, origin: origin)
        drawCheckboxes(glyphsToShow: glyphsToShow, origin: origin)
        drawTableBlocks(glyphsToShow: glyphsToShow, origin: origin)
    }

    // MARK: - Dividers

    private func drawDividers(glyphsToShow: NSRange, origin: NSPoint) {
        for div in dividers {
            let gi = glyphIndexForCharacter(at: div.charIndex)
            guard NSLocationInRange(gi, glyphsToShow) else { continue }
            let lineRect = lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
            guard let tc = textContainer(forGlyphAt: gi, effectiveRange: nil) else { continue }
            let pad = tc.lineFragmentPadding
            let y = origin.y + lineRect.midY
            let line = NSBezierPath()
            line.move(to: NSPoint(x: origin.x + pad, y: y))
            line.line(to: NSPoint(x: origin.x + lineRect.width - pad, y: y))
            line.lineWidth = 1
            div.color.setStroke()
            line.stroke()
        }
    }

    // MARK: - Checkboxes

    private func drawCheckboxes(glyphsToShow: NSRange, origin: NSPoint) {
        for cb in checkboxes {
            let gi = firstVisibleGlyph(from: cb.visibleCharIndex)
            guard NSLocationInRange(gi, glyphsToShow) else { continue }
            let lineRect = lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
            let size: CGFloat = 14
            let rect = NSRect(
                x: origin.x + cb.indent + 1,
                y: origin.y + lineRect.origin.y + (lineRect.height - size) / 2,
                width: size, height: size
            )
            drawCheckbox(in: rect, checked: cb.checked)
        }
    }

    func checkboxRect(for cb: CheckboxDrawInfo, origin: NSPoint) -> NSRect {
        let gi = firstVisibleGlyph(from: cb.visibleCharIndex)
        let lineRect = lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
        let size: CGFloat = 14
        return NSRect(
            x: origin.x + cb.indent + 1,
            y: origin.y + lineRect.origin.y + (lineRect.height - size) / 2,
            width: size, height: size
        )
    }

    /// Find the first non-null glyph starting from a character index.
    /// When bold markers (**) immediately follow the checkbox prefix,
    /// visibleCharIndex points to a hidden glyph — scan forward to find a real one.
    private func firstVisibleGlyph(from charIndex: Int) -> Int {
        let maxChar = textStorage?.length ?? 0
        var idx = charIndex
        while idx < maxChar {
            let gi = glyphIndexForCharacter(at: idx)
            if propertyForGlyph(at: gi) != .null { return gi }
            idx += 1
        }
        return glyphIndexForCharacter(at: charIndex)
    }

    private func drawCheckbox(in rect: NSRect, checked: Bool) {
        let box = rect.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3)

        if checked {
            NSColor.controlAccentColor.setFill()
            path.fill()
            let check = NSBezierPath()
            check.lineWidth = 1.8
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            let bx = box.minX, by = box.minY, bw = box.width, bh = box.height
            check.move(to: NSPoint(x: bx + bw * 0.2, y: by + bh * 0.5))
            check.line(to: NSPoint(x: bx + bw * 0.42, y: by + bh * 0.72))
            check.line(to: NSPoint(x: bx + bw * 0.8, y: by + bh * 0.25))
            NSColor.white.setStroke()
            check.stroke()
        } else {
            NSColor.tertiaryLabelColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    // MARK: - Tables

    private func drawTableBlocks(glyphsToShow: NSRange, origin: NSPoint) {
        for table in tableBlocks {
            var rowRects: [(TableBlockDrawInfo.Row, NSRect)] = []
            for row in table.rows {
                let gi = glyphIndexForCharacter(at: row.charIndex)
                guard NSLocationInRange(gi, glyphsToShow) else { continue }
                rowRects.append((row, lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)))
            }
            guard !rowRects.isEmpty else { continue }
            let gi0 = glyphIndexForCharacter(at: rowRects[0].0.charIndex)
            guard let tc = textContainer(forGlyphAt: gi0, effectiveRange: nil) else { continue }

            let tableX = origin.x + tc.lineFragmentPadding
            let tableW = table.columnWidths.reduce(0, +)
            let topY = origin.y + rowRects.first!.1.origin.y
            let bottomY = origin.y + rowRects.last!.1.origin.y + rowRects.last!.1.height
            let outerRect = NSRect(x: tableX, y: topY, width: tableW, height: bottomY - topY)

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: outerRect, xRadius: 6, yRadius: 6).addClip()

            for (row, lineRect) in rowRects {
                drawTableRow(row: row, table: table, lineRect: lineRect, tableX: tableX, origin: origin)
            }

            NSGraphicsContext.restoreGraphicsState()

            let border = NSBezierPath(roundedRect: outerRect, xRadius: 6, yRadius: 6)
            border.lineWidth = 0.5
            table.borderColor.setStroke()
            border.stroke()
        }
    }

    private func drawTableRow(
        row: TableBlockDrawInfo.Row, table: TableBlockDrawInfo,
        lineRect: NSRect, tableX: CGFloat, origin: NSPoint
    ) {
        let tableW = table.columnWidths.reduce(0, +)
        let rowY = origin.y + lineRect.origin.y
        let rowRect = NSRect(x: tableX, y: rowY, width: tableW, height: lineRect.height)

        if row.isSeparator {
            table.borderColor.setStroke()
            let sep = NSBezierPath()
            sep.move(to: NSPoint(x: rowRect.minX, y: rowRect.midY))
            sep.line(to: NSPoint(x: rowRect.maxX, y: rowRect.midY))
            sep.lineWidth = 1
            sep.stroke()
            return
        }

        drawTableRowBackground(row: row, table: table, rowRect: rowRect)
        drawActiveCellHighlight(row: row, table: table, tableX: tableX, rowRect: rowRect)
        drawTableCellText(row: row, table: table, lineRect: lineRect, tableX: tableX, rowY: rowY)
        drawTableRowGrid(table: table, rowRect: rowRect, isHeader: row.isHeader)
    }

    private func drawActiveCellHighlight(
        row: TableBlockDrawInfo.Row, table: TableBlockDrawInfo, tableX: CGFloat, rowRect: NSRect
    ) {
        guard let active = activeTableCell,
              active.rowCharIndex == row.charIndex,
              active.colIndex < table.columnWidths.count else { return }
        var x = tableX
        for i in 0..<active.colIndex { x += table.columnWidths[i] }
        let rect = NSRect(x: x, y: rowRect.minY, width: table.columnWidths[active.colIndex], height: rowRect.height)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(rect: rect).fill()
    }

    private func drawTableRowBackground(row: TableBlockDrawInfo.Row, table: TableBlockDrawInfo, rowRect: NSRect) {
        if row.isHeader {
            table.headerBgColor.setFill()
            NSBezierPath(rect: rowRect).fill()
        } else if row.dataRowIndex >= 0 && row.dataRowIndex % 2 == 1 {
            table.stripeBgColor.setFill()
            NSBezierPath(rect: rowRect).fill()
        }
    }

    private func drawTableCellText(
        row: TableBlockDrawInfo.Row, table: TableBlockDrawInfo,
        lineRect: NSRect, tableX: CGFloat, rowY: CGFloat
    ) {
        let font = row.isHeader ? table.headerFont : table.font
        let rowIndex = table.rows.firstIndex(where: { $0.charIndex == row.charIndex }) ?? 0
        let rowH = rowIndex < table.rowHeights.count ? table.rowHeights[rowIndex] : lineRect.height
        var x = tableX
        for (col, cell) in row.cells.enumerated() where col < table.columnWidths.count {
            let w = table.columnWidths[col]
            let isActive = activeTableCell?.rowCharIndex == row.charIndex && activeTableCell?.colIndex == col
            if !isActive {
                let cellW = w - table.cellPadding * 2
                let styled = Self.styledCellText(cell, font: font, color: table.textColor, boldColor: table.boldColor, italicColor: table.italicColor)
                let textRect = styled.boundingRect(
                    with: NSSize(width: cellW, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin]
                )
                let yOff = (rowH - textRect.height) / 2
                let rect = NSRect(x: x + table.cellPadding, y: rowY + max(yOff, table.cellPadding), width: cellW, height: rowH - table.cellPadding)
                styled.draw(with: rect, options: [.usesLineFragmentOrigin])
            }
            x += w
        }
    }

    private static let cellTextRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "(\\*\\*(.+?)\\*\\*|(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*))")
    }()

    static func styledCellText(
        _ text: String, font: NSFont, color: NSColor,
        boldColor: NSColor, italicColor: NSColor
    ) -> NSAttributedString {
        let baseAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let nsText = text as NSString

        struct Span {
            let text: String
            let bold: Bool
            let italic: Bool
        }

        var spans: [Span] = []
        let regex = cellTextRegex

        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            if match.range.location > cursor {
                let plain = nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                spans.append(Span(text: plain, bold: false, italic: false))
            }
            if match.range(at: 2).location != NSNotFound {
                spans.append(Span(text: nsText.substring(with: match.range(at: 2)), bold: true, italic: false))
            } else if match.range(at: 3).location != NSNotFound {
                spans.append(Span(text: nsText.substring(with: match.range(at: 3)), bold: false, italic: true))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < nsText.length {
            spans.append(Span(text: nsText.substring(from: cursor), bold: false, italic: false))
        }
        if spans.isEmpty {
            return NSAttributedString(string: text, attributes: baseAttrs)
        }

        let result = NSMutableAttributedString()
        for span in spans {
            var f = font
            var spanColor = color
            if span.bold {
                f = NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
                spanColor = boldColor
            }
            if span.italic {
                f = NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
                spanColor = italicColor
            }
            result.append(NSAttributedString(string: span.text, attributes: [
                .font: f, .foregroundColor: spanColor
            ]))
        }
        return result
    }

    private func drawTableRowGrid(table: TableBlockDrawInfo, rowRect: NSRect, isHeader: Bool) {
        table.borderColor.withAlphaComponent(0.4).setStroke()
        var x = rowRect.minX
        for (col, w) in table.columnWidths.enumerated() {
            x += w
            if col < table.columnWidths.count - 1 {
                let vLine = NSBezierPath()
                vLine.move(to: NSPoint(x: x, y: rowRect.minY))
                vLine.line(to: NSPoint(x: x, y: rowRect.maxY))
                vLine.lineWidth = 0.5
                vLine.stroke()
            }
        }
        let hLine = NSBezierPath()
        hLine.move(to: NSPoint(x: rowRect.minX, y: rowRect.maxY))
        hLine.line(to: NSPoint(x: rowRect.maxX, y: rowRect.maxY))
        hLine.lineWidth = isHeader ? 1 : 0.5
        table.borderColor.withAlphaComponent(isHeader ? 0.8 : 0.3).setStroke()
        hLine.stroke()
    }
}

import AppKit

// MARK: - CheckboxTextView

class CheckboxTextView: NSTextView {
    weak var coordinator: MarkdownCoordinator?
    private var cellEditorView: NSTextView?
    private var cellEditorScrollView: NSScrollView?
    private var editingCell: TableCellRef?
    private var originalCellValue: String = ""

    var maxContentWidth: CGFloat = 0 {
        didSet { updateHorizontalInset() }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateHorizontalInset()
    }

    private func updateHorizontalInset() {
        guard maxContentWidth > 0 else {
            textContainerInset = NSSize(width: 16, height: 16)
            return
        }
        let available = bounds.width
        let hInset = max(16, (available - maxContentWidth) / 2)
        textContainerInset = NSSize(width: hInset, height: 16)
    }

    private var trackingArea: NSTrackingArea?
    private var isOverCheckbox = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isPointOverCheckbox(point) {
            if !isOverCheckbox {
                NSCursor.pointingHand.set()
                isOverCheckbox = true
            }
        } else {
            if isOverCheckbox {
                NSCursor.iBeam.set()
                isOverCheckbox = false
            }
            super.mouseMoved(with: event)
        }
    }

    private func isPointOverCheckbox(_ point: NSPoint) -> Bool {
        guard let lm = layoutManager as? HidingLayoutManager else { return false }
        for cb in lm.checkboxes {
            let rect = lm.checkboxRect(for: cb, origin: textContainerOrigin)
            if rect.insetBy(dx: -4, dy: -4).contains(point) { return true }
        }
        return false
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let lm = layoutManager as? HidingLayoutManager {
            for cb in lm.checkboxes {
                let rect = lm.checkboxRect(for: cb, origin: textContainerOrigin)
                if rect.insetBy(dx: -4, dy: -4).contains(point) {
                    commitCellEditing()
                    coordinator?.toggleCheckbox(at: cb.charIndex)
                    return
                }
            }
        }

        if let ref = tableCellAtPoint(point) {
            if editingCell != nil { commitCellEditing() }
            beginCellEditing(ref)
            return
        }

        commitCellEditing()
        super.mouseDown(with: event)
    }

    // MARK: - Table cell hit testing

    private func tableCellAtPoint(_ point: NSPoint) -> TableCellRef? {
        guard let lm = layoutManager as? HidingLayoutManager else { return nil }
        let origin = textContainerOrigin
        for table in lm.tableBlocks {
            for row in table.rows where !row.isSeparator {
                let gi = lm.glyphIndexForCharacter(at: row.charIndex)
                let lineRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
                let rowY = origin.y + lineRect.origin.y
                guard point.y >= rowY && point.y <= rowY + lineRect.height else { continue }
                guard let tc = lm.textContainer(forGlyphAt: gi, effectiveRange: nil) else { continue }
                var x = origin.x + tc.lineFragmentPadding
                for col in 0..<min(table.columnWidths.count, row.cells.count) {
                    let w = table.columnWidths[col]
                    if point.x >= x && point.x <= x + w {
                        return TableCellRef(rowCharIndex: row.charIndex, colIndex: col)
                    }
                    x += w
                }
            }
        }
        return nil
    }

    // MARK: - Cell editing

    private func cellEditorFrame(for ref: TableCellRef) -> NSRect? {
        guard let lm = layoutManager as? HidingLayoutManager else { return nil }
        for table in lm.tableBlocks {
            guard let row = table.rows.first(where: { $0.charIndex == ref.rowCharIndex }),
                  ref.colIndex < table.columnWidths.count else { continue }
            let gi = lm.glyphIndexForCharacter(at: row.charIndex)
            let lineRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
            guard let tc = lm.textContainer(forGlyphAt: gi, effectiveRange: nil) else { return nil }
            let rowIndex = table.rows.firstIndex(where: { $0.charIndex == row.charIndex }) ?? 0
            let rowH = rowIndex < table.rowHeights.count ? table.rowHeights[rowIndex] : lineRect.height
            var x = textContainerOrigin.x + tc.lineFragmentPadding
            for i in 0..<ref.colIndex { x += table.columnWidths[i] }
            let w = table.columnWidths[ref.colIndex]
            return NSRect(
                x: x + table.cellPadding,
                y: textContainerOrigin.y + lineRect.origin.y + table.cellPadding,
                width: w - table.cellPadding * 2,
                height: rowH - table.cellPadding * 2
            )
        }
        return nil
    }

    private func beginCellEditing(_ ref: TableCellRef) {
        guard let lm = layoutManager as? HidingLayoutManager,
              let frame = cellEditorFrame(for: ref) else { return }

        var cellText = ""
        var cellFont: NSFont = .systemFont(ofSize: 13)
        var cellColor: NSColor = .labelColor
        var cellBoldColor: NSColor = .labelColor
        var cellItalicColor: NSColor = .labelColor
        for table in lm.tableBlocks {
            guard let row = table.rows.first(where: { $0.charIndex == ref.rowCharIndex }),
                  ref.colIndex < row.cells.count else { continue }
            cellText = row.cells[ref.colIndex]
            cellFont = row.isHeader ? table.headerFont : table.font
            cellColor = table.textColor
            cellBoldColor = table.boldColor
            cellItalicColor = table.italicColor
        }

        let (scrollView, editor) = getOrCreateCellEditor()
        let styledStr = Self.styledCellString(cellText, font: cellFont, color: cellColor, boldColor: cellBoldColor, italicColor: cellItalicColor)
        editor.textStorage?.setAttributedString(styledStr)
        editor.textContainer?.containerSize = NSSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true

        // Calculate text height to vertically center the editor in the cell
        let textRect = styledStr.boundingRect(
            with: NSSize(width: frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin]
        )
        let textH = ceil(textRect.height)
        let yOff = max((frame.height - textH) / 2, 0)
        var editorFrame = frame
        editorFrame.origin.y += yOff
        editorFrame.size.height = max(textH, cellFont.pointSize + 4)
        scrollView.frame = editorFrame
        scrollView.isHidden = false

        editingCell = ref
        originalCellValue = cellText
        lm.activeTableCell = ref
        setNeedsDisplay(bounds)
        window?.makeFirstResponder(editor)
    }

    private func getOrCreateCellEditor() -> (NSScrollView, NSTextView) {
        if let sv = cellEditorScrollView, let tv = cellEditorView { return (sv, tv) }
        let tv = CellEditorTextView()
        tv.isRichText = true
        tv.drawsBackground = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.parentCheckboxTextView = self

        let sv = NSScrollView()
        sv.documentView = tv
        sv.drawsBackground = false
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.borderType = .noBorder
        addSubview(sv)

        cellEditorScrollView = sv
        cellEditorView = tv
        return (sv, tv)
    }

    func commitCellEditing() {
        guard let sv = cellEditorScrollView, let editor = cellEditorView,
              let ref = editingCell, !sv.isHidden else { return }
        let newValue = editor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        sv.isHidden = true
        editingCell = nil
        (layoutManager as? HidingLayoutManager)?.activeTableCell = nil

        if newValue != originalCellValue {
            coordinator?.updateTableCell(ref: ref, newValue: newValue)
        } else {
            setNeedsDisplay(bounds)
        }
    }

    private func cancelCellEditing() {
        guard let sv = cellEditorScrollView, editingCell != nil else { return }
        sv.isHidden = true
        editingCell = nil
        (layoutManager as? HidingLayoutManager)?.activeTableCell = nil
        setNeedsDisplay(bounds)
        window?.makeFirstResponder(self)
    }

    func repositionCellEditorIfNeeded() {
        guard let ref = editingCell, let sv = cellEditorScrollView,
              let editor = cellEditorView, !sv.isHidden,
              let frame = cellEditorFrame(for: ref) else { return }
        editor.textContainer?.containerSize = NSSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude)
        let textRect = (editor.textStorage as NSAttributedString?)?.boundingRect(
            with: NSSize(width: frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin]
        ) ?? .zero
        let textH = ceil(textRect.height)
        let yOff = max((frame.height - textH) / 2, 0)
        var editorFrame = frame
        editorFrame.origin.y += yOff
        editorFrame.size.height = max(textH, 20)
        sv.frame = editorFrame
    }

    func handleCellEditorTab(forward: Bool) {
        let lastRef = editingCell
        commitCellEditing()
        if let ref = lastRef {
            navigateToCell(from: ref, forward: forward)
        }
    }

    func handleCellEditorEscape() {
        cancelCellEditing()
    }

    // MARK: - Inline markdown styling for cell editor

    static func styledCellString(
        _ text: String, font: NSFont, color: NSColor,
        boldColor: NSColor, italicColor: NSColor
    ) -> NSAttributedString {
        let baseAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let result = NSMutableAttributedString(string: text, attributes: baseAttrs)
        let nsText = text as NSString
        let markerColor = NSColor.tertiaryLabelColor

        // Bold: **text**
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*") {
            for match in boldRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let contentRange = match.range(at: 1)
                let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                result.addAttributes([.font: boldFont, .foregroundColor: boldColor], range: contentRange)
                let openRange = NSRange(location: match.range.location, length: 2)
                let closeRange = NSRange(location: match.range.location + match.range.length - 2, length: 2)
                result.addAttribute(.foregroundColor, value: markerColor, range: openRange)
                result.addAttribute(.foregroundColor, value: markerColor, range: closeRange)
            }
        }

        // Italic: *text* (not preceded/followed by *)
        if let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)") {
            for match in italicRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let contentRange = match.range(at: 1)
                let currentFont = result.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? font
                let italicFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                result.addAttributes([.font: italicFont, .foregroundColor: italicColor], range: contentRange)
                let openRange = NSRange(location: match.range.location, length: 1)
                let closeRange = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                result.addAttribute(.foregroundColor, value: markerColor, range: openRange)
                result.addAttribute(.foregroundColor, value: markerColor, range: closeRange)
            }
        }

        return result
    }

    // MARK: - Tab navigation

    private func navigateToCell(from ref: TableCellRef, forward: Bool) {
        guard let lm = layoutManager as? HidingLayoutManager else { return }
        for table in lm.tableBlocks {
            let dataRows = table.rows.filter { !$0.isSeparator }
            guard let rowIdx = dataRows.firstIndex(where: {
                $0.charIndex == ref.rowCharIndex
            }) else { continue }
            let numCols = min(table.columnWidths.count, dataRows[rowIdx].cells.count)

            var nextCol = ref.colIndex + (forward ? 1 : -1)
            var nextRowIdx = rowIdx

            if nextCol >= numCols {
                nextCol = 0; nextRowIdx += 1
            } else if nextCol < 0 {
                nextCol = numCols - 1; nextRowIdx -= 1
            }

            guard nextRowIdx >= 0, nextRowIdx < dataRows.count else { return }
            let nextRef = TableCellRef(
                rowCharIndex: dataRows[nextRowIdx].charIndex, colIndex: nextCol
            )
            beginCellEditing(nextRef)
            return
        }
    }
}

// MARK: - CellEditorTextView

class CellEditorTextView: NSTextView {
    weak var parentCheckboxTextView: CheckboxTextView?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            parentCheckboxTextView?.handleCellEditorEscape()
            return
        }
        if event.keyCode == 48 { // Tab
            let forward = !event.modifierFlags.contains(.shift)
            parentCheckboxTextView?.handleCellEditorTab(forward: forward)
            return
        }
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) { // Return (not shift-return)
            parentCheckboxTextView?.commitCellEditing()
            return
        }
        super.keyDown(with: event)
    }
}

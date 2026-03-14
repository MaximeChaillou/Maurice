import AppKit
import SwiftUI

struct MarkdownView: NSViewRepresentable {
    @Binding var content: String
    var theme: MarkdownTheme = MarkdownTheme()

    func makeCoordinator() -> MarkdownCoordinator { MarkdownCoordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CheckboxTextView()
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        textView.drawsBackground = false
        textView.maxContentWidth = theme.maxContentWidth
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )
        textView.allowsUndo = true
        textView.delegate = context.coordinator

        let layoutManager = HidingLayoutManager()
        textView.textContainer?.replaceLayoutManager(layoutManager)

        context.coordinator.textView = textView
        context.coordinator.hidingLM = layoutManager
        textView.coordinator = context.coordinator

        textView.string = content

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        return scrollView
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: MarkdownCoordinator) {
        coordinator.stopObservingFrame()
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CheckboxTextView else { return }

        textView.maxContentWidth = theme.maxContentWidth
        let needsStyling = !context.coordinator.hasAppliedInitialStyling
        let themeChanged = context.coordinator.parent.theme != theme
        if textView.string != content || themeChanged {
            let sel = textView.selectedRange()
            if textView.string != content {
                textView.string = content
                let safePos = min(sel.location, (content as NSString).length)
                textView.setSelectedRange(NSRange(location: safePos, length: 0))
            }
            context.coordinator.parent = self
            context.coordinator.applyMarkdownStyling()
            context.coordinator.hasAppliedInitialStyling = true
            context.coordinator.startObservingFrame()
        } else if needsStyling {
            context.coordinator.parent = self
            context.coordinator.applyMarkdownStyling()
            context.coordinator.hasAppliedInitialStyling = true
            context.coordinator.startObservingFrame()
        } else {
            context.coordinator.parent = self
        }
    }
}

// MARK: - TableRowContext

struct TableRowContext {
    let isHeader: Bool
    let isSeparator: Bool
    let dataRowIndex: Int
}

// MARK: - Coordinator

@MainActor
class MarkdownCoordinator: NSObject, NSTextViewDelegate {
    var parent: MarkdownView
    weak var textView: CheckboxTextView?
    var hidingLM: HidingLayoutManager?
    private var cursorLine: Int = -1
    var hasAppliedInitialStyling = false
    private var lastKnownWidth: CGFloat = 0
    private var frameObserver: NSObjectProtocol?

    var hiddenRanges: [NSRange] = []
    var replacements: [Int: UniChar] = [:]
    var checkboxInfos: [CheckboxDrawInfo] = []
    var dividerInfos: [DividerDrawInfo] = []
    var tableRowContexts: [Int: TableRowContext] = [:]
    var tableBlockInfos: [TableBlockDrawInfo] = []

    init(_ parent: MarkdownView) { self.parent = parent }

    func startObservingFrame() {
        guard frameObserver == nil, let textView else { return }
        textView.postsFrameChangedNotifications = true
        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: textView, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let tv = self.textView else { return }
                let w = tv.bounds.width
                guard w > 0, abs(w - self.lastKnownWidth) > 1 else { return }
                self.lastKnownWidth = w
                self.applyMarkdownStyling()
            }
        }
    }

    func stopObservingFrame() {
        if let observer = frameObserver {
            NotificationCenter.default.removeObserver(observer)
            frameObserver = nil
        }
    }

    var theme: MarkdownTheme { parent.theme }

    // MARK: - Font resolution

    func resolveFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let name = theme.fontName
        if name == "System" {
            return .systemFont(ofSize: size, weight: weight)
        } else if name == "System Mono" {
            return .monospacedSystemFont(ofSize: size, weight: weight)
        } else if let font = NSFont(name: name, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    func monoFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }

    // MARK: - Delegate

    nonisolated func textDidChange(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard let textView else { return }
            parent.content = textView.string
            applyMarkdownStyling()
        }
    }

    nonisolated func textViewDidChangeSelection(_ notification: Notification) {
        MainActor.assumeIsolated {
            let newLine = currentLineIndex()
            if newLine != cursorLine {
                cursorLine = newLine
                applyMarkdownStyling()
            }
        }
    }

    // MARK: - Line tracking

    func currentLineIndex() -> Int {
        guard let textView, let window = textView.window,
              window.firstResponder === textView else { return -1 }
        let pos = min(textView.selectedRange().location, (textView.string as NSString).length)
        return (textView.string as NSString).substring(to: pos)
            .components(separatedBy: "\n").count - 1
    }

    // MARK: - Styling

    func applyMarkdownStyling() {
        guard let textView, let storage = textView.textStorage, let lm = hidingLM else { return }
        let text = textView.string
        let nsText = text as NSString
        guard nsText.length > 0 else { return }

        let lines = text.components(separatedBy: "\n")
        let activeLine = currentLineIndex()
        let savedSel = textView.selectedRange()

        hiddenRanges = []
        replacements = [:]
        checkboxInfos = []
        dividerInfos = []
        tableRowContexts = [:]
        tableBlockInfos = []

        storage.beginEditing()

        let defaultFont = resolveFont(size: theme.baseFontSize)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.lineSpacing = 4
        let fullRange = NSRange(location: 0, length: nsText.length)
        storage.setAttributes([
            .font: defaultFont,
            .foregroundColor: theme.bodyColor.nsColor,
            .paragraphStyle: defaultPara
        ], range: fullRange)

        let codeLines = detectCodeBlockLines(lines)
        styleAllLines(lines: lines, activeLine: activeLine, codeLines: codeLines, storage: storage)
        storage.endEditing()

        commitLayoutChanges(lm: lm, fullRange: fullRange)
        textView.setSelectedRange(savedSel)
    }

    private func detectCodeBlockLines(_ lines: [String]) -> Set<Int> {
        var inCodeBlock = false
        var codeLines = Set<Int>()
        for (i, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.insert(i)
                inCodeBlock.toggle()
            } else if inCodeBlock {
                codeLines.insert(i)
            }
        }
        return codeLines
    }

    private func styleAllLines(
        lines: [String], activeLine: Int, codeLines: Set<Int>, storage: NSTextStorage
    ) {
        buildTableInfos(lines: lines, codeLines: codeLines)
        var offset = 0
        for (i, line) in lines.enumerated() {
            let len = (line as NSString).length
            let range = NSRange(location: offset, length: len)
            let active = i == activeLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if codeLines.contains(i) {
                styleCodeLine(storage: storage, trimmed: trimmed, range: range, active: active)
            } else {
                styleMarkdownLine(LineContext(
                    storage: storage, line: line, trimmed: trimmed,
                    range: range, offset: offset, active: active
                ))
                if !active && tableRowContexts[offset] == nil {
                    styleInlineMarkdown(storage: storage, range: range)
                }
            }

            offset += len + 1
        }
    }

    private func commitLayoutChanges(lm: HidingLayoutManager, fullRange: NSRange) {
        var indexSet = Set<Int>()
        for range in hiddenRanges {
            for i in range.location..<(range.location + range.length) {
                indexSet.insert(i)
            }
        }
        lm.hiddenCharIndexes = indexSet
        lm.glyphReplacements = replacements
        lm.checkboxes = checkboxInfos
        lm.dividers = dividerInfos
        lm.tableBlocks = tableBlockInfos
        lm.invalidateGlyphs(forCharacterRange: fullRange, changeInLength: 0, actualCharacterRange: nil)
        lm.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
        textView?.repositionCellEditorIfNeeded()
    }

    // MARK: - Table block detection

    private func buildTableInfos(lines: [String], codeLines: Set<Int> = []) {
        var offsets: [Int] = []
        var offset = 0
        for line in lines {
            offsets.append(offset)
            offset += (line as NSString).length + 1
        }

        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard !codeLines.contains(i), trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { i += 1; continue }
            let tableStart = i
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                guard t.hasPrefix("|") && t.hasSuffix("|") else { break }
                i += 1
            }
            if let block = parseTableBlock(lines: lines, range: tableStart..<i, offsets: offsets) {
                tableBlockInfos.append(block)
                for row in block.rows {
                    tableRowContexts[row.charIndex] = TableRowContext(
                        isHeader: row.isHeader, isSeparator: row.isSeparator, dataRowIndex: row.dataRowIndex
                    )
                }
            }
        }
    }

    private func parseTableBlock(lines: [String], range: Range<Int>, offsets: [Int]) -> TableBlockDrawInfo? {
        let font = resolveFont(size: theme.baseFontSize)
        let headerFont = resolveFont(size: theme.baseFontSize, weight: .semibold)
        let cellPadding: CGFloat = 10

        var separatorLine: Int?
        for li in range {
            let t = lines[li].trimmingCharacters(in: .whitespaces)
            if t.contains("---") && !t.contains(where: { $0.isLetter }) { separatorLine = li; break }
        }

        var rows: [TableBlockDrawInfo.Row] = []
        var dataIdx = 0
        for li in range {
            let t = lines[li].trimmingCharacters(in: .whitespaces)
            let isSep = t.contains("---") && !t.contains(where: { $0.isLetter })
            let isHdr = separatorLine != nil && li < separatorLine!
            let cells = parseCells(t)
            rows.append(TableBlockDrawInfo.Row(
                charIndex: offsets[li], cells: cells,
                isHeader: isHdr, isSeparator: isSep,
                dataRowIndex: (!isSep && !isHdr) ? dataIdx : -1
            ))
            if !isSep && !isHdr { dataIdx += 1 }
        }

        let numCols = rows.map(\.cells.count).max() ?? 0
        guard numCols > 0 else { return nil }
        let colWidths = computeColumnWidths(rows: rows, numCols: numCols, font: font, headerFont: headerFont, padding: cellPadding)
        let rowHeights = computeRowHeights(rows: rows, colWidths: colWidths, font: font, headerFont: headerFont, padding: cellPadding)

        return TableBlockDrawInfo(
            rows: rows, columnWidths: colWidths, rowHeights: rowHeights, cellPadding: cellPadding,
            font: font, headerFont: headerFont,
            textColor: theme.bodyColor.nsColor,
            boldColor: theme.boldColor.nsColor,
            italicColor: theme.italicColor.nsColor,
            headerBgColor: NSColor.controlAccentColor.withAlphaComponent(0.08),
            stripeBgColor: NSColor.labelColor.withAlphaComponent(0.04),
            borderColor: NSColor.separatorColor
        )
    }

    private func computeColumnWidths(
        rows: [TableBlockDrawInfo.Row], numCols: Int,
        font: NSFont, headerFont: NSFont, padding: CGFloat
    ) -> [CGFloat] {
        var maxWidths = [CGFloat](repeating: 0, count: numCols)
        for row in rows where !row.isSeparator {
            let attrs: [NSAttributedString.Key: Any] = [.font: row.isHeader ? headerFont : font]
            for (col, cell) in row.cells.enumerated() where col < numCols {
                maxWidths[col] = max(maxWidths[col], (cell as NSString).size(withAttributes: attrs).width)
            }
        }
        var widths = maxWidths.map { $0 + padding * 2 }

        // Cap total width to available text container width
        let availableWidth = textView?.textContainer?.containerSize.width
            ?? textView?.bounds.width ?? 600
        let pad = textView?.textContainer?.lineFragmentPadding ?? 5
        let maxTotal = availableWidth - pad * 2
        let total = widths.reduce(0, +)
        if total > maxTotal && maxTotal > 0 {
            let minColWidth: CGFloat = 60
            let scale = maxTotal / total
            widths = widths.map { max($0 * scale, minColWidth) }
            // Re-normalize if minColWidth pushed us over
            let newTotal = widths.reduce(0, +)
            if newTotal > maxTotal {
                let excess = newTotal - maxTotal
                let shrinkable = widths.filter { $0 > minColWidth }
                let shrinkAmount = excess / CGFloat(max(shrinkable.count, 1))
                widths = widths.map { $0 > minColWidth ? max($0 - shrinkAmount, minColWidth) : $0 }
            }
        }
        return widths
    }

    private func computeRowHeights(
        rows: [TableBlockDrawInfo.Row], colWidths: [CGFloat],
        font: NSFont, headerFont: NSFont, padding: CGFloat
    ) -> [CGFloat] {
        rows.map { row in
            guard !row.isSeparator else { return 4 }
            let f = row.isHeader ? headerFont : font
            var maxH: CGFloat = f.pointSize + 8
            for (col, cell) in row.cells.enumerated() where col < colWidths.count {
                let cellW = colWidths[col] - padding * 2
                let styled = HidingLayoutManager.styledCellText(cell, font: f, color: .labelColor, boldColor: .labelColor, italicColor: .labelColor)
                let textRect = styled.boundingRect(
                    with: NSSize(width: max(cellW, 1), height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin]
                )
                maxH = max(maxH, textRect.height + padding * 2)
            }
            return maxH
        }
    }

    private func parseCells(_ trimmed: String) -> [String] {
        let inner = String(trimmed.dropFirst().dropLast())
        return inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Table cell editing & Checkbox toggle

extension MarkdownCoordinator {
    func updateTableCell(ref: TableCellRef, newValue: String) {
        guard let textView, let storage = textView.textStorage else { return }
        let nsText = textView.string as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: ref.rowCharIndex, length: 0))
        let lineText = nsText.substring(with: lineRange)

        var pipePositions: [Int] = []
        for (i, char) in lineText.enumerated() where char == "|" { pipePositions.append(i) }
        guard ref.colIndex + 1 < pipePositions.count else { return }

        let cellStart = pipePositions[ref.colIndex] + 1
        let cellEnd = pipePositions[ref.colIndex + 1]
        let cellRange = NSRange(location: ref.rowCharIndex + cellStart, length: cellEnd - cellStart)

        storage.replaceCharacters(in: cellRange, with: " \(newValue) ")
        parent.content = textView.string
        applyMarkdownStyling()
    }

    func toggleCheckbox(at charIndex: Int) {
        guard let textView, let storage = textView.textStorage else { return }
        let nsText = textView.string as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: charIndex, length: 0))
        let line = nsText.substring(with: lineRange)
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("- [ ] ") else { return }

        let bracketContent = charIndex + 3
        let replaceRange = NSRange(location: bracketContent, length: 1)

        if trimmed.hasPrefix("- [ ] ") {
            storage.replaceCharacters(in: replaceRange, with: "x")
        } else {
            storage.replaceCharacters(in: replaceRange, with: " ")
        }

        parent.content = textView.string
        applyMarkdownStyling()
    }
}

import AppKit

// MARK: - Incremental cursor restyle

extension MarkdownCoordinator {
    /// Restyle only the old and new active lines instead of the entire document.
    func restyleLines(old oldLine: Int, new newLine: Int) {
        guard let textView, let storage = textView.textStorage, let lm = hidingLM else { return }
        let text = textView.string
        guard !(text as NSString).isEqual(to: "") else { return }

        let lines = text.components(separatedBy: "\n")
        let codeLines = detectCodeBlockLines(lines)
        let offsets = computeLineOffsets(lines)

        let affectedLines = Set([oldLine, newLine].filter { $0 >= 0 && $0 < lines.count })
        guard !affectedLines.isEmpty else { return }

        purgeDrawInfoForLines(affectedLines, lines: lines, offsets: offsets)
        buildTableInfos(lines: lines, codeLines: codeLines)

        let ctx = LineRestylingContext(lines: lines, offsets: offsets, codeLines: codeLines)
        storage.beginEditing()
        restyleAffectedLines(affectedLines, newLine: newLine, ctx: ctx, storage: storage)
        storage.endEditing()

        invalidateAffectedLines(affectedLines, lines: lines, offsets: offsets, lm: lm)
        syncLayoutManagerData(lm: lm)
    }

    struct LineRestylingContext {
        let lines: [String]
        let offsets: [Int]
        let codeLines: Set<Int>
    }

    private func computeLineOffsets(_ lines: [String]) -> [Int] {
        var offsets: [Int] = []
        var off = 0
        for line in lines {
            offsets.append(off)
            off += (line as NSString).length + 1
        }
        return offsets
    }

    private func purgeDrawInfoForLines(_ affected: Set<Int>, lines: [String], offsets: [Int]) {
        for lineIdx in affected {
            let lineStart = offsets[lineIdx]
            let lineEnd = lineStart + (lines[lineIdx] as NSString).length
            hiddenRanges.removeAll { $0.location >= lineStart && $0.location < lineEnd }
            for k in lineStart..<lineEnd { replacements.removeValue(forKey: k) }
            checkboxInfos.removeAll { $0.charIndex >= lineStart && $0.charIndex < lineEnd }
            dividerInfos.removeAll { $0.charIndex >= lineStart && $0.charIndex < lineEnd }
            tableRowContexts.removeValue(forKey: lineStart)
        }
    }

    private func restyleAffectedLines(
        _ affected: Set<Int>, newLine: Int, ctx: LineRestylingContext, storage: NSTextStorage
    ) {
        let defaultFont = resolveFont(size: theme.baseFontSize)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.lineSpacing = 4
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: defaultFont, .foregroundColor: theme.bodyColor.nsColor, .paragraphStyle: defaultPara
        ]

        for lineIdx in affected {
            let line = ctx.lines[lineIdx]
            let range = NSRange(location: ctx.offsets[lineIdx], length: (line as NSString).length)
            let active = lineIdx == newLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            storage.setAttributes(defaultAttrs, range: range)

            if ctx.codeLines.contains(lineIdx) {
                styleCodeLine(storage: storage, trimmed: trimmed, range: range, active: active)
            } else {
                styleMarkdownLine(LineContext(
                    storage: storage, line: line, trimmed: trimmed,
                    range: range, offset: ctx.offsets[lineIdx], active: active
                ))
                if !active && tableRowContexts[ctx.offsets[lineIdx]] == nil {
                    styleInlineMarkdown(storage: storage, range: range)
                }
            }
        }
    }

    private func invalidateAffectedLines(
        _ affected: Set<Int>, lines: [String], offsets: [Int], lm: HidingLayoutManager
    ) {
        for lineIdx in affected {
            let range = NSRange(location: offsets[lineIdx], length: (lines[lineIdx] as NSString).length)
            lm.invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
            lm.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        }
    }

    private func syncLayoutManagerData(lm: HidingLayoutManager) {
        var indexSet = IndexSet()
        for range in hiddenRanges {
            indexSet.insert(integersIn: range.location..<(range.location + range.length))
        }
        lm.hiddenCharIndexes = indexSet
        lm.glyphReplacements = replacements
        lm.checkboxes = checkboxInfos
        lm.dividers = dividerInfos
        lm.tableBlocks = tableBlockInfos
        textView?.repositionCellEditorIfNeeded()
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

        let isChecked = trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
            || trimmed.hasPrefix("- [x]\u{00A0}") || trimmed.hasPrefix("- [X]\u{00A0}")
        let isUnchecked = trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [\u{00A0}] ")
            || trimmed.hasPrefix("- [ ]\u{00A0}") || trimmed.hasPrefix("- [\u{00A0}]\u{00A0}")
        guard isChecked || isUnchecked else { return }

        let bracketContent = charIndex + 3
        let replaceRange = NSRange(location: bracketContent, length: 1)

        if isUnchecked {
            storage.replaceCharacters(in: replaceRange, with: "x")
        } else {
            storage.replaceCharacters(in: replaceRange, with: " ")
        }

        parent.content = textView.string
        applyMarkdownStyling()
    }
}

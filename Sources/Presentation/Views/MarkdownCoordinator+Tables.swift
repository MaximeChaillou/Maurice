import AppKit

// MARK: - Table block detection

extension MarkdownCoordinator {
    func buildTableInfos(lines: [String], codeLines: Set<Int> = []) {
        let currentContent = textView?.string ?? ""
        let currentWidth = textView?.textContainer?.containerSize.width
            ?? textView?.bounds.width ?? 600

        // Reuse cached table blocks if content and width haven't changed
        if currentContent == cachedTableContent && abs(currentWidth - cachedTableWidth) < 1 {
            tableBlockInfos = cachedTableBlocks
            tableRowContexts = cachedTableRowContexts
            return
        }

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

        cachedTableContent = currentContent
        cachedTableWidth = currentWidth
        cachedTableBlocks = tableBlockInfos
        cachedTableRowContexts = tableRowContexts
    }

    private func parseTableBlock(lines: [String], range: Range<Int>, offsets: [Int]) -> TableBlockDrawInfo? {
        let font = resolveFont(size: theme.baseFontSize)
        let headerFont = resolveFont(size: theme.baseFontSize, weight: .semibold)
        let cellPadding: CGFloat = 10

        let rows = buildTableRows(lines: lines, range: range, offsets: offsets)
        let numCols = rows.map(\.cells.count).max() ?? 0
        guard numCols > 0 else { return nil }

        let measurement = cachedOrMeasureTable(
            lines: lines, range: range,
            input: TableMeasureInput(
                rows: rows, numCols: numCols,
                font: font, headerFont: headerFont, padding: cellPadding
            )
        )

        return TableBlockDrawInfo(
            rows: rows, columnWidths: measurement.columnWidths, rowHeights: measurement.rowHeights,
            cellPadding: cellPadding, font: font, headerFont: headerFont,
            textColor: theme.bodyColor.nsColor,
            boldColor: theme.boldColor.nsColor,
            italicColor: theme.italicColor.nsColor,
            headerBgColor: NSColor.controlAccentColor.withAlphaComponent(0.08),
            stripeBgColor: NSColor.labelColor.withAlphaComponent(0.04),
            borderColor: NSColor.separatorColor
        )
    }

    private func buildTableRows(
        lines: [String], range: Range<Int>, offsets: [Int]
    ) -> [TableBlockDrawInfo.Row] {
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
        return rows
    }

    private struct TableMeasureInput {
        let rows: [TableBlockDrawInfo.Row]
        let numCols: Int
        let font: NSFont
        let headerFont: NSFont
        let padding: CGFloat
    }

    private func cachedOrMeasureTable(
        lines: [String], range: Range<Int>, input: TableMeasureInput
    ) -> TableMeasurement {
        let availableWidth = textView?.textContainer?.containerSize.width
            ?? textView?.bounds.width ?? 600
        let tableText = range.map { lines[$0] }.joined(separator: "\n")
        let cacheKey = "\(Int(availableWidth.rounded()))|\(tableText)"
        if let cached = tableMeasurementCache[cacheKey] { return cached }

        let colWidths = computeColumnWidths(
            rows: input.rows, numCols: input.numCols,
            font: input.font, headerFont: input.headerFont, padding: input.padding
        )
        let rowHeights = computeRowHeights(
            rows: input.rows, colWidths: colWidths,
            font: input.font, headerFont: input.headerFont, padding: input.padding
        )
        let measurement = TableMeasurement(columnWidths: colWidths, rowHeights: rowHeights)
        if tableMeasurementCache.count >= 64 {
            tableMeasurementCache.removeAll(keepingCapacity: true)
        }
        tableMeasurementCache[cacheKey] = measurement
        return measurement
    }

    private func computeColumnWidths(
        rows: [TableBlockDrawInfo.Row], numCols: Int,
        font: NSFont, headerFont: NSFont, padding: CGFloat
    ) -> [CGFloat] {
        var idealWidths = [CGFloat](repeating: 0, count: numCols)
        var minWordWidths = [CGFloat](repeating: 0, count: numCols)

        for row in rows where !row.isSeparator {
            let f = row.isHeader ? headerFont : font
            let attrs: [NSAttributedString.Key: Any] = [.font: f]
            for (col, cell) in row.cells.enumerated() where col < numCols {
                idealWidths[col] = max(idealWidths[col], (cell as NSString).size(withAttributes: attrs).width)
                for word in cell.split(separator: " ") {
                    let w = (String(word) as NSString).size(withAttributes: attrs).width
                    minWordWidths[col] = max(minWordWidths[col], w)
                }
            }
        }

        var widths = idealWidths.map { $0 + padding * 2 }
        let minWidths = minWordWidths.map { $0 + padding * 2 }

        let availableWidth = textView?.textContainer?.containerSize.width
            ?? textView?.bounds.width ?? 600
        let pad = textView?.textContainer?.lineFragmentPadding ?? 5
        let maxTotal = availableWidth - pad * 2
        let total = widths.reduce(0, +)

        if total > maxTotal && maxTotal > 0 {
            let minTotal = minWidths.reduce(0, +)
            if minTotal >= maxTotal {
                widths = minWidths
            } else {
                let remaining = maxTotal - minTotal
                let extras = zip(widths, minWidths).map { $0 - $1 }
                let totalExtra = extras.reduce(0, +)
                if totalExtra > 0 {
                    widths = zip(minWidths, extras).map { $0 + $1 * (remaining / totalExtra) }
                } else {
                    widths = minWidths
                }
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
                let styled = HidingLayoutManager.styledCellText(
                    cell, font: f, color: .labelColor, boldColor: .labelColor, italicColor: .labelColor
                )
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

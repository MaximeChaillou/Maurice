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
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
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
        let contentChanged = textView.string != content
        if themeChanged {
            context.coordinator.invalidateStyleCaches()
        }
        if contentChanged || themeChanged {
            let sel = textView.selectedRange()
            context.coordinator.parent = self
            if contentChanged {
                // Set content via NSTextStorage inside applyMarkdownStyling's beginEditing/endEditing
                // to avoid a double layout pass (textView.string = triggers layout, then styling triggers it again)
                context.coordinator.applyMarkdownStyling(newContent: content)
                let safePos = min(sel.location, (content as NSString).length)
                textView.setSelectedRange(NSRange(location: safePos, length: 0))
            } else {
                context.coordinator.applyMarkdownStyling()
            }
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

    /// Cache key for table block computations — avoids expensive text measurement when only cursor moves.
    var cachedTableContent: String?
    var cachedTableWidth: CGFloat = 0
    var cachedTableBlocks: [TableBlockDrawInfo] = []
    var cachedTableRowContexts: [Int: TableRowContext] = [:]

    /// Per-table measurement cache. Key: "<width>|<tableText>". Lets us reuse column widths / row heights
    /// when only text outside the table has changed, so offsets shift but the table layout is untouched.
    struct TableMeasurement {
        let columnWidths: [CGFloat]
        let rowHeights: [CGFloat]
    }
    var tableMeasurementCache: [String: TableMeasurement] = [:]

    /// Resolved-font cache keyed by "<name>|<size>|<weight>". Avoids repeated NSFont lookups during
    /// styling passes that request the same font dozens of times.
    private var fontCache: [String: NSFont] = [:]

    /// Clear caches that depend on theme (font measurements, font lookups).
    /// Call when the theme changes or the coordinator is dismantled.
    func invalidateStyleCaches() {
        tableMeasurementCache.removeAll(keepingCapacity: true)
        fontCache.removeAll(keepingCapacity: true)
        cachedTableContent = nil
        cachedTableBlocks = []
        cachedTableRowContexts = [:]
    }

    init(_ parent: MarkdownView) { self.parent = parent }

    private var pendingStylingWorkItem: DispatchWorkItem?

    /// Schedule a full re-style, coalescing rapid calls (typing, frame changes).
    /// `delay` of 0 still routes through the main queue to batch multiple triggers per run-loop tick.
    func scheduleApplyMarkdownStyling(delay: TimeInterval = 0.1) {
        pendingStylingWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.applyMarkdownStyling() }
        }
        pendingStylingWorkItem = item
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
            DispatchQueue.main.async(execute: item)
        }
    }

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
                self.scheduleApplyMarkdownStyling(delay: 0)
            }
        }
    }

    func stopObservingFrame() {
        if let observer = frameObserver {
            NotificationCenter.default.removeObserver(observer)
            frameObserver = nil
        }
        pendingStylingWorkItem?.cancel()
        pendingStylingWorkItem = nil
    }

    var theme: MarkdownTheme { parent.theme }

    // MARK: - Font resolution

    func resolveFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let name = theme.fontName
        let key = "\(name)|\(size)|\(weight.rawValue)"
        if let cached = fontCache[key] { return cached }
        let font: NSFont
        if name == "System" {
            font = .systemFont(ofSize: size, weight: weight)
        } else if name == "System Mono" {
            font = .monospacedSystemFont(ofSize: size, weight: weight)
        } else if let f = NSFont(name: name, size: size) {
            font = f
        } else {
            font = .systemFont(ofSize: size, weight: weight)
        }
        fontCache[key] = font
        return font
    }

    func monoFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }

    // MARK: - Delegate

    nonisolated func textDidChange(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard let textView else { return }
            parent.content = textView.string
            scheduleApplyMarkdownStyling()
        }
    }

    nonisolated func textViewDidChangeSelection(_ notification: Notification) {
        MainActor.assumeIsolated {
            let newLine = currentLineIndex()
            if newLine != cursorLine {
                let oldLine = cursorLine
                cursorLine = newLine
                restyleLines(old: oldLine, new: newLine)
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

    func applyMarkdownStyling(newContent: String? = nil) {
        guard let textView, let storage = textView.textStorage, let lm = hidingLM else { return }

        storage.beginEditing()

        // Replace content inside the batch to avoid a separate layout pass
        if let newContent {
            let fullReplace = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: fullReplace, with: newContent)
        }

        let text = textView.string
        let nsText = text as NSString
        guard nsText.length > 0 else { storage.endEditing(); return }

        let lines = text.components(separatedBy: "\n")
        let activeLine = currentLineIndex()
        let savedSel = textView.selectedRange()

        hiddenRanges = []
        replacements = [:]
        checkboxInfos = []
        dividerInfos = []
        tableRowContexts = [:]
        tableBlockInfos = []

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

    func detectCodeBlockLines(_ lines: [String]) -> Set<Int> {
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
        var indexSet = IndexSet()
        for range in hiddenRanges {
            indexSet.insert(integersIn: range.location..<(range.location + range.length))
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
}

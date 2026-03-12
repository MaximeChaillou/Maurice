import AppKit
import SwiftUI

struct BlockEditField: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var textColor: NSColor = .labelColor
    var initialClickScreenPoint: CGPoint?
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onEscape: () -> Void
    var onFocusLost: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ArrowTextView()
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.borderType = .noBorder

        let screenPoint = initialClickScreenPoint
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            if let screenPt = screenPoint,
               let window = textView.window,
               let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                let windowPt = window.convertPoint(fromScreen: screenPt)
                let viewPt = textView.convert(windowPt, from: nil)
                let origin = textView.textContainerOrigin
                let containerPt = NSPoint(x: viewPt.x - origin.x, y: viewPt.y - origin.y)
                let charIndex = layoutManager.characterIndex(
                    for: containerPt,
                    in: textContainer,
                    fractionOfDistanceBetweenInsertionPoints: nil
                )
                let safeIndex = min(charIndex, textView.string.count)
                textView.setSelectedRange(NSRange(location: safeIndex, length: 0))
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ArrowTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.arrowUpHandler = onArrowUp
        textView.arrowDownHandler = onArrowDown
        textView.escapeHandler = onEscape
        context.coordinator.parent = self
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockEditField
        weak var textView: NSTextView?

        init(_ parent: BlockEditField) { self.parent = parent }

        nonisolated func textDidChange(_ notification: Notification) {
            MainActor.assumeIsolated {
                parent.text = textView?.string ?? ""
            }
        }

        nonisolated func textDidEndEditing(_ notification: Notification) {
            MainActor.assumeIsolated {
                parent.onFocusLost()
            }
        }
    }
}

private class ArrowTextView: NSTextView {
    var arrowUpHandler: (() -> Void)?
    var arrowDownHandler: (() -> Void)?
    var escapeHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 126 where cursorOnFirstLine:
            arrowUpHandler?()
        case 125 where cursorOnLastLine:
            arrowDownHandler?()
        case 53:
            escapeHandler?()
        default:
            super.keyDown(with: event)
        }
    }

    private var cursorOnFirstLine: Bool {
        let pos = selectedRange().location
        return !string.prefix(pos).contains("\n")
    }

    private var cursorOnLastLine: Bool {
        let pos = selectedRange().location
        let idx = string.index(string.startIndex, offsetBy: min(pos, string.count))
        return !string[idx...].contains("\n")
    }
}

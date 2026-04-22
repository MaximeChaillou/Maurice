#if DEBUG
import AppKit

enum DebugIconOverlay {
    @MainActor
    static func apply() {
        guard let appIcon = NSApp.applicationIconImage else { return }
        let size = appIcon.size
        let newIcon = NSImage(size: size)
        newIcon.lockFocus()
        appIcon.draw(in: NSRect(origin: .zero, size: size))

        let bannerHeight = size.height * 0.22
        let bannerRect = NSRect(x: 0, y: 0, width: size.width, height: bannerHeight)
        NSColor(red: 0.9, green: 0.3, blue: 0.0, alpha: 0.85).setFill()
        bannerRect.fill()

        let fontSize = bannerHeight * 0.55
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white,
        ]
        let text = "DEBUG" as NSString
        let textSize = text.size(withAttributes: attrs)
        let textPoint = NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (bannerHeight - textSize.height) / 2
        )
        text.draw(at: textPoint, withAttributes: attrs)

        newIcon.unlockFocus()
        NSApp.applicationIconImage = newIcon
    }
}
#endif

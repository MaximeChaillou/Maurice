import AppKit

// MARK: - MarkdownTheme (Sage tokens)
//
// Stateless design-tokens struct sourced from `share/maurice-markdown.css`.
// All colors are dynamic NSColors that resolve against the view's effective
// appearance, so the same theme automatically renders in light and dark mode.

struct MarkdownTheme: Equatable {

    // MARK: - Layout

    var maxContentWidth: CGFloat = 890

    // MARK: - Typography

    var fontName: String = "System"
    var baseFontSize: CGFloat = 14.5

    var h1FontSize: CGFloat = 30
    var h2FontSize: CGFloat = 22
    var h3FontSize: CGFloat = 17
    var h4FontSize: CGFloat = 15

    var h1Bold = true
    var h2Bold = true
    var h3Bold = true
    var h4Bold = true
    var h1Italic = false
    var h2Italic = false
    var h3Italic = false
    var h4Italic = false
    var h1Underline = false
    var h2Underline = false
    var h3Underline = false
    var h4Underline = false

    var quoteBold = false
    var quoteItalic = true
    var quoteUnderline = false

    // MARK: - Color tokens

    var bodyColor: NSColor { .sageBody }
    var textMutedColor: NSColor { .sageTextMuted }
    var textFaintColor: NSColor { .sageTextFaint }
    var headingColor: NSColor { .sageHeading }
    var boldColor: NSColor { .sageBold }
    var italicColor: NSColor { .sageBody }

    var h1Color: NSColor { .sageHeading }
    var h2Color: NSColor { .sageHeading }
    var h3Color: NSColor { .sageHeading }
    var h4Color: NSColor { .sageHeading }

    var quoteColor: NSColor { .sageQuote }
    var quoteRuleColor: NSColor { .sageAccentRule }

    var codeColor: NSColor { .sageCode }
    var codeBackgroundColor: NSColor { .sageCodeInlineBg }
    var codeBlockBackgroundColor: NSColor { .sageCodeBlockBg }
    var codeBlockBorderColor: NSColor { .sageCodeBlockBorder }

    var linkColor: NSColor { .sageAccentText }
    var dividerColor: NSColor { .sageRule }

    var accentColor: NSColor { .sageAccent }
    var taskBorderColor: NSColor { .sageTaskBorder }

    var tableHeaderBgColor: NSColor { .sageTableHeaderBg }
    var tableRowAltBgColor: NSColor { .sageTableRowAlt }
    var tableBorderColor: NSColor { .sageTableBorder }
}

// MARK: - Sage palette

extension NSColor {
    fileprivate static let sageBody             = sageDynamic(light: sageRGBA(0, 0, 0, 0.84), dark: sageRGBA(255, 255, 255, 0.88))
    fileprivate static let sageTextMuted        = sageDynamic(light: sageRGBA(0, 0, 0, 0.55), dark: sageRGBA(255, 255, 255, 0.60))
    fileprivate static let sageTextFaint        = sageDynamic(light: sageRGBA(0, 0, 0, 0.40), dark: sageRGBA(255, 255, 255, 0.42))
    fileprivate static let sageHeading          = sageDynamic(light: sageRGBA(0, 0, 0, 0.92), dark: sageRGBA(255, 255, 255, 0.95))
    fileprivate static let sageBold             = sageDynamic(light: sageRGBA(0, 0, 0, 0.95), dark: sageRGBA(255, 255, 255, 0.98))
    fileprivate static let sageQuote            = sageDynamic(light: sageRGBA(0, 0, 0, 0.70), dark: sageRGBA(255, 255, 255, 0.78))
    fileprivate static let sageRule             = sageDynamic(light: sageRGBA(0, 0, 0, 0.10), dark: sageRGBA(255, 255, 255, 0.10))
    fileprivate static let sageCode             = sageDynamic(light: sageRGBA(0, 0, 0, 0.85), dark: sageRGBA(255, 255, 255, 0.92))
    fileprivate static let sageCodeInlineBg     = sageDynamic(light: sageRGBA(0, 0, 0, 0.045), dark: sageRGBA(255, 255, 255, 0.07))
    fileprivate static let sageCodeBlockBg      = sageDynamic(light: sageRGBA(0, 0, 0, 0.035), dark: sageRGBA(0, 0, 0, 0.28))
    fileprivate static let sageCodeBlockBorder  = sageDynamic(light: sageRGBA(0, 0, 0, 0.06), dark: sageRGBA(255, 255, 255, 0.06))
    fileprivate static let sageTableHeaderBg    = sageDynamic(light: sageRGBA(0, 0, 0, 0.035), dark: sageRGBA(255, 255, 255, 0.04))
    fileprivate static let sageTableRowAlt      = sageDynamic(light: sageRGBA(0, 0, 0, 0.018), dark: sageRGBA(255, 255, 255, 0.02))
    fileprivate static let sageTableBorder      = sageDynamic(light: sageRGBA(0, 0, 0, 0.08), dark: sageRGBA(255, 255, 255, 0.08))
    fileprivate static let sageAccentText       = sageDynamic(light: sageRGB(0x03, 0x6B, 0x79), dark: sageRGB(0x6E, 0xE8, 0xF5))
    fileprivate static let sageAccentRule       = sageDynamic(light: sageRGBA(0, 200, 220, 0.40), dark: sageRGBA(0, 200, 220, 0.50))
    fileprivate static let sageAccent           = sageRGB(0x00, 0xC8, 0xDC)
    fileprivate static let sageTaskBorder       = sageDynamic(light: sageRGBA(0, 0, 0, 0.22), dark: sageRGBA(255, 255, 255, 0.28))
}

// MARK: - Helpers

private func sageRGBA(_ red: Int, _ green: Int, _ blue: Int, _ alpha: Double) -> NSColor {
    NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
}

private func sageRGB(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
    sageRGBA(red, green, blue, 1)
}

private func sageDynamic(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? dark : light
    }
}

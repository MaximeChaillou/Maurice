import SwiftUI

struct MarkdownTheme: PersistentCodable, Equatable {
    // MARK: - Background

    var backgroundColor: CodableColor = CodableColor(.clear)

    // MARK: - Typography

    var fontName: String = "System"
    var baseFontSize: CGFloat = 14

    // MARK: - Body text

    var bodyColor: CodableColor = CodableColor(.labelColor)

    // MARK: - Headings

    var h1Color: CodableColor = CodableColor(.labelColor)
    var h1FontSize: CGFloat = 26
    var h1Bold: Bool = true
    var h1Italic: Bool = false
    var h1Underline: Bool = false

    var h2Color: CodableColor = CodableColor(.labelColor)
    var h2FontSize: CGFloat = 20
    var h2Bold: Bool = true
    var h2Italic: Bool = false
    var h2Underline: Bool = false

    var h3Color: CodableColor = CodableColor(.labelColor)
    var h3FontSize: CGFloat = 17
    var h3Bold: Bool = true
    var h3Italic: Bool = false
    var h3Underline: Bool = false

    // MARK: - Bold & italic

    var boldColor: CodableColor = CodableColor(.labelColor)
    var italicColor: CodableColor = CodableColor(.labelColor)

    // MARK: - Blockquotes

    var quoteColor: CodableColor = CodableColor(.secondaryLabelColor)
    var quoteBold: Bool = false
    var quoteItalic: Bool = true
    var quoteUnderline: Bool = false

    // MARK: - Code

    var codeColor: CodableColor = CodableColor(.labelColor)
    var codeBackgroundColor: CodableColor = CodableColor(.quaternaryLabelColor)

    // MARK: - Links / dividers

    var dividerColor: CodableColor = CodableColor(.separatorColor)

    // MARK: - Layout

    var maxContentWidth: CGFloat = 700

    // MARK: - Codable

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = MarkdownTheme()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = try c.decodeIfPresent(CodableColor.self, forKey: .backgroundColor) ?? defaults.backgroundColor
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? defaults.fontName
        baseFontSize = try c.decodeIfPresent(CGFloat.self, forKey: .baseFontSize) ?? defaults.baseFontSize
        bodyColor = try c.decodeIfPresent(CodableColor.self, forKey: .bodyColor) ?? defaults.bodyColor
        h1Color = try c.decodeIfPresent(CodableColor.self, forKey: .h1Color) ?? defaults.h1Color
        h1FontSize = try c.decodeIfPresent(CGFloat.self, forKey: .h1FontSize) ?? defaults.h1FontSize
        h1Bold = try c.decodeIfPresent(Bool.self, forKey: .h1Bold) ?? defaults.h1Bold
        h1Italic = try c.decodeIfPresent(Bool.self, forKey: .h1Italic) ?? defaults.h1Italic
        h1Underline = try c.decodeIfPresent(Bool.self, forKey: .h1Underline) ?? defaults.h1Underline
        h2Color = try c.decodeIfPresent(CodableColor.self, forKey: .h2Color) ?? defaults.h2Color
        h2FontSize = try c.decodeIfPresent(CGFloat.self, forKey: .h2FontSize) ?? defaults.h2FontSize
        h2Bold = try c.decodeIfPresent(Bool.self, forKey: .h2Bold) ?? defaults.h2Bold
        h2Italic = try c.decodeIfPresent(Bool.self, forKey: .h2Italic) ?? defaults.h2Italic
        h2Underline = try c.decodeIfPresent(Bool.self, forKey: .h2Underline) ?? defaults.h2Underline
        h3Color = try c.decodeIfPresent(CodableColor.self, forKey: .h3Color) ?? defaults.h3Color
        h3FontSize = try c.decodeIfPresent(CGFloat.self, forKey: .h3FontSize) ?? defaults.h3FontSize
        h3Bold = try c.decodeIfPresent(Bool.self, forKey: .h3Bold) ?? defaults.h3Bold
        h3Italic = try c.decodeIfPresent(Bool.self, forKey: .h3Italic) ?? defaults.h3Italic
        h3Underline = try c.decodeIfPresent(Bool.self, forKey: .h3Underline) ?? defaults.h3Underline
        boldColor = try c.decodeIfPresent(CodableColor.self, forKey: .boldColor) ?? defaults.boldColor
        italicColor = try c.decodeIfPresent(CodableColor.self, forKey: .italicColor) ?? defaults.italicColor
        quoteColor = try c.decodeIfPresent(CodableColor.self, forKey: .quoteColor) ?? defaults.quoteColor
        quoteBold = try c.decodeIfPresent(Bool.self, forKey: .quoteBold) ?? defaults.quoteBold
        quoteItalic = try c.decodeIfPresent(Bool.self, forKey: .quoteItalic) ?? defaults.quoteItalic
        quoteUnderline = try c.decodeIfPresent(Bool.self, forKey: .quoteUnderline) ?? defaults.quoteUnderline
        codeColor = try c.decodeIfPresent(CodableColor.self, forKey: .codeColor) ?? defaults.codeColor
        codeBackgroundColor = try c.decodeIfPresent(CodableColor.self, forKey: .codeBackgroundColor) ?? defaults.codeBackgroundColor
        dividerColor = try c.decodeIfPresent(CodableColor.self, forKey: .dividerColor) ?? defaults.dividerColor
        maxContentWidth = try c.decodeIfPresent(CGFloat.self, forKey: .maxContentWidth) ?? defaults.maxContentWidth
    }

    // MARK: - Persistence

    static var persistenceURL: URL {
        AppSettings.themeFileURL
    }
}

// MARK: - CodableColor

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(_ nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        red = Double(c.redComponent)
        green = Double(c.greenComponent)
        blue = Double(c.blueComponent)
        alpha = Double(c.alphaComponent)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }
}

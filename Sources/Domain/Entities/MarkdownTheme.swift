import SwiftUI

struct MarkdownTheme: Codable, Equatable {
    // MARK: - Background

    var backgroundColor: CodableColor = CodableColor(red: 0.1099, green: 0.1298, blue: 0.1549, alpha: 0.6049)

    // MARK: - Typography

    var fontName: String = "Helvetica Neue"
    var baseFontSize: CGFloat = 16

    // MARK: - Body text

    var bodyColor: CodableColor = CodableColor(red: 0.854, green: 0.854, blue: 0.854)

    // MARK: - Headings

    var h1Color: CodableColor = CodableColor(red: 0.854, green: 0.854, blue: 0.854)
    var h1FontSize: CGFloat = 26
    var h1Bold: Bool = true
    var h1Italic: Bool = false
    var h1Underline: Bool = false

    var h2Color: CodableColor = CodableColor(red: 0.1821, green: 0.4999, blue: 0.9470)
    var h2FontSize: CGFloat = 22
    var h2Bold: Bool = true
    var h2Italic: Bool = false
    var h2Underline: Bool = false

    var h3Color: CodableColor = CodableColor(red: 0.4855, green: 0.5008, blue: 0.9454)
    var h3FontSize: CGFloat = 18
    var h3Bold: Bool = true
    var h3Italic: Bool = false
    var h3Underline: Bool = false

    // MARK: - Bold & italic

    var boldColor: CodableColor = CodableColor(red: 0.8563, green: 0.5481, blue: 0.8177)
    var italicColor: CodableColor = CodableColor(red: 0.854, green: 0.854, blue: 0.854)

    // MARK: - Blockquotes

    var quoteColor: CodableColor = CodableColor(red: 0.2449, green: 0.7068, blue: 0.7484)
    var quoteBold: Bool = false
    var quoteItalic: Bool = true
    var quoteUnderline: Bool = false

    // MARK: - Code

    var codeColor: CodableColor = CodableColor(red: 0.854, green: 0.854, blue: 0.854)
    var codeBackgroundColor: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 0.4012)

    // MARK: - Links / dividers

    var dividerColor: CodableColor = CodableColor(red: 0.3584, green: 0.4181, blue: 0.4885)

    // MARK: - Layout

    var maxContentWidth: CGFloat = 890

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

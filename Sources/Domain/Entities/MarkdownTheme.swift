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
        backgroundColor = try c.valueOrDefault(forKey: .backgroundColor, default: defaults.backgroundColor)
        fontName = try c.valueOrDefault(forKey: .fontName, default: defaults.fontName)
        baseFontSize = try c.valueOrDefault(forKey: .baseFontSize, default: defaults.baseFontSize)
        bodyColor = try c.valueOrDefault(forKey: .bodyColor, default: defaults.bodyColor)
        h1Color = try c.valueOrDefault(forKey: .h1Color, default: defaults.h1Color)
        h1FontSize = try c.valueOrDefault(forKey: .h1FontSize, default: defaults.h1FontSize)
        h1Bold = try c.valueOrDefault(forKey: .h1Bold, default: defaults.h1Bold)
        h1Italic = try c.valueOrDefault(forKey: .h1Italic, default: defaults.h1Italic)
        h1Underline = try c.valueOrDefault(forKey: .h1Underline, default: defaults.h1Underline)
        h2Color = try c.valueOrDefault(forKey: .h2Color, default: defaults.h2Color)
        h2FontSize = try c.valueOrDefault(forKey: .h2FontSize, default: defaults.h2FontSize)
        h2Bold = try c.valueOrDefault(forKey: .h2Bold, default: defaults.h2Bold)
        h2Italic = try c.valueOrDefault(forKey: .h2Italic, default: defaults.h2Italic)
        h2Underline = try c.valueOrDefault(forKey: .h2Underline, default: defaults.h2Underline)
        h3Color = try c.valueOrDefault(forKey: .h3Color, default: defaults.h3Color)
        h3FontSize = try c.valueOrDefault(forKey: .h3FontSize, default: defaults.h3FontSize)
        h3Bold = try c.valueOrDefault(forKey: .h3Bold, default: defaults.h3Bold)
        h3Italic = try c.valueOrDefault(forKey: .h3Italic, default: defaults.h3Italic)
        h3Underline = try c.valueOrDefault(forKey: .h3Underline, default: defaults.h3Underline)
        boldColor = try c.valueOrDefault(forKey: .boldColor, default: defaults.boldColor)
        italicColor = try c.valueOrDefault(forKey: .italicColor, default: defaults.italicColor)
        quoteColor = try c.valueOrDefault(forKey: .quoteColor, default: defaults.quoteColor)
        quoteBold = try c.valueOrDefault(forKey: .quoteBold, default: defaults.quoteBold)
        quoteItalic = try c.valueOrDefault(forKey: .quoteItalic, default: defaults.quoteItalic)
        quoteUnderline = try c.valueOrDefault(forKey: .quoteUnderline, default: defaults.quoteUnderline)
        codeColor = try c.valueOrDefault(forKey: .codeColor, default: defaults.codeColor)
        codeBackgroundColor = try c.valueOrDefault(forKey: .codeBackgroundColor, default: defaults.codeBackgroundColor)
        dividerColor = try c.valueOrDefault(forKey: .dividerColor, default: defaults.dividerColor)
        maxContentWidth = try c.valueOrDefault(forKey: .maxContentWidth, default: defaults.maxContentWidth)
    }
}

// MARK: - Defensive Decoding Helper

extension KeyedDecodingContainer {
    func valueOrDefault<T: Decodable>(forKey key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? defaultValue
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

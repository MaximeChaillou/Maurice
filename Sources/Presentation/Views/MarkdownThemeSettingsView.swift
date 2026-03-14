import SwiftUI

struct MarkdownThemeSettingsView: View {
    @Binding var theme: MarkdownTheme
    @State private var availableFonts: [String] = []

    private let togglesWidth: CGFloat = 100
    private let pickerWidth: CGFloat = 44

    var body: some View {
        ScrollView {
            Form {
                generalSection
                layoutSection
                headingsSection
                textSection
                quoteSection
                codeSection
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 420)
        .onAppear { loadFonts() }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section("Général") {
            colorRow("Arrière-plan", color: $theme.backgroundColor)

            Picker("Typographie", selection: $theme.fontName) {
                Text("System").tag("System")
                Text("System Mono").tag("System Mono")
                ForEach(availableFonts, id: \.self) { name in
                    Text(name).tag(name)
                }
            }

            fontSizeRow("Taille de base", size: $theme.baseFontSize, range: 10...24)
        }
    }

    private var layoutSection: some View {
        Section("Mise en page") {
            fontSizeRow("Largeur max du contenu", size: $theme.maxContentWidth, range: 300...1200)
        }
    }

    private var headingsSection: some View {
        Section("Titres") {
            headingRow("H1", bindings: HeadingBindings(
                color: $theme.h1Color, size: $theme.h1FontSize, sizeRange: 16...48,
                bold: $theme.h1Bold, italic: $theme.h1Italic, underline: $theme.h1Underline))
            headingRow("H2", bindings: HeadingBindings(
                color: $theme.h2Color, size: $theme.h2FontSize, sizeRange: 14...40,
                bold: $theme.h2Bold, italic: $theme.h2Italic, underline: $theme.h2Underline))
            headingRow("H3", bindings: HeadingBindings(
                color: $theme.h3Color, size: $theme.h3FontSize, sizeRange: 12...36,
                bold: $theme.h3Bold, italic: $theme.h3Italic, underline: $theme.h3Underline))
        }
    }

    private var textSection: some View {
        Section("Texte") {
            colorRow("Corps", color: $theme.bodyColor)
            colorRow("Gras", color: $theme.boldColor)
            colorRow("Italique", color: $theme.italicColor)
            colorRow("Séparateur", color: $theme.dividerColor)
        }
    }

    private var quoteSection: some View {
        Section("Citations") {
            styledRow("Citation", color: $theme.quoteColor,
                      bold: $theme.quoteBold, italic: $theme.quoteItalic, underline: $theme.quoteUnderline)
        }
    }

    private var codeSection: some View {
        Section("Code") {
            colorRow("Texte", color: $theme.codeColor)
            colorRow("Arrière-plan", color: $theme.codeBackgroundColor)
        }
    }

    // MARK: - Reusable rows

    private func colorRow(_ label: String, color: Binding<CodableColor>) -> some View {
        HStack {
            Text(label)
            Spacer()
            colorPicker(color)
                .frame(width: pickerWidth, alignment: .trailing)
        }
    }

    private func fontSizeRow(_ label: String, size: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Slider(value: size, in: range, step: 1)
                .frame(width: 160)
            Text("\(Int(size.wrappedValue)) pt")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    private struct HeadingBindings {
        let color: Binding<CodableColor>
        let size: Binding<CGFloat>
        let sizeRange: ClosedRange<CGFloat>
        let bold: Binding<Bool>
        let italic: Binding<Bool>
        let underline: Binding<Bool>
    }

    private func headingRow(_ label: String, bindings: HeadingBindings) -> some View {
        HStack(spacing: 36) {
            Text(label).frame(width: 24, alignment: .leading)
            HStack(spacing: 6) {
                Slider(value: bindings.size, in: bindings.sizeRange, step: 1)
                Text("\(Int(bindings.size.wrappedValue)) pt")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            Spacer()
            styleToggles(bold: bindings.bold, italic: bindings.italic, underline: bindings.underline)
                .frame(width: togglesWidth, alignment: .trailing)
            colorPicker(bindings.color)
                .frame(width: pickerWidth, alignment: .trailing)
        }
    }

    private func styledRow(
        _ label: String, color: Binding<CodableColor>,
        bold: Binding<Bool>, italic: Binding<Bool>, underline: Binding<Bool>
    ) -> some View {
        HStack(spacing: 36) {
            Text(label)
            Spacer()
            styleToggles(bold: bold, italic: italic, underline: underline)
                .frame(width: togglesWidth, alignment: .trailing)
            colorPicker(color)
                .frame(width: pickerWidth, alignment: .trailing)
        }
    }

    private func colorPicker(_ color: Binding<CodableColor>) -> some View {
        let binding = Binding<Color>(
            get: { color.wrappedValue.color },
            set: { if let c = NSColor($0).usingColorSpace(.sRGB) { color.wrappedValue = CodableColor(c) } }
        )
        return ColorPicker("", selection: binding, supportsOpacity: true)
            .labelsHidden()
    }

    private func styleToggles(bold: Binding<Bool>, italic: Binding<Bool>, underline: Binding<Bool>) -> some View {
        HStack(spacing: 2) {
            Toggle(isOn: bold) { Image(systemName: "bold") }
            Toggle(isOn: italic) { Image(systemName: "italic") }
            Toggle(isOn: underline) { Image(systemName: "underline") }
        }
        .toggleStyle(.button)
    }

    // MARK: - Helpers

    private func loadFonts() {
        let fm = NSFontManager.shared
        availableFonts = fm.availableFontFamilies.filter { family in
            let members = fm.availableMembers(ofFontFamily: family) ?? []
            let traits = members.compactMap { $0[3] as? UInt }
            let hasBold = traits.contains { $0 & UInt(NSFontTraitMask.boldFontMask.rawValue) != 0 }
            let hasItalic = traits.contains { $0 & UInt(NSFontTraitMask.italicFontMask.rawValue) != 0 }
            return hasBold && hasItalic
        }.sorted()
    }
}

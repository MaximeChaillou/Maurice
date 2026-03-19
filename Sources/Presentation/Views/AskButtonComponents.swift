import SwiftUI

// MARK: - Tool group (collapsible)

struct AskToolGroupView: View {
    let lines: [AskConversationLine]
    @State private var isOpen = false

    private var summary: String {
        let count = lines.count
        return "\(count) outil\(count > 1 ? "s" : "") utilisé\(count > 1 ? "s" : "")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text(summary)
                        .font(AskFont.caption)
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(AskFont.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Inline Markdown parser

enum InlineMarkdownParser {
    static func headingLevel(_ text: String) -> (level: Int, content: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var level = 0
        for char in trimmed {
            if char == "#" { level += 1 } else { break }
        }
        guard level > 0, level <= 3, trimmed.dropFirst(level).first == " " else {
            return (0, text)
        }
        return (level, String(trimmed.dropFirst(level + 1)))
    }

    static func parse(_ text: String) -> AttributedString {
        parseBold(text[...])
    }

    private static func parseBold(_ remaining: Substring) -> AttributedString {
        var result = AttributedString()
        var rest = remaining

        while !rest.isEmpty {
            if let openRange = rest.range(of: "**") {
                let before = rest[rest.startIndex..<openRange.lowerBound]
                if !before.isEmpty { result.append(parseItalic(before)) }
                let afterOpen = rest[openRange.upperBound...]
                if let closeRange = afterOpen.range(of: "**") {
                    var bold = parseItalic(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    for run in bold.runs {
                        bold[run.range].inlinePresentationIntent =
                            (bold[run.range].inlinePresentationIntent ?? []).union(.stronglyEmphasized)
                    }
                    result.append(bold)
                    rest = afterOpen[closeRange.upperBound...]
                } else {
                    result.append(AttributedString("**"))
                    rest = afterOpen
                }
            } else {
                result.append(parseItalic(rest))
                break
            }
        }
        return result
    }

    private static func parseItalic(_ remaining: Substring) -> AttributedString {
        var result = AttributedString()
        var rest = remaining

        while !rest.isEmpty {
            if let openRange = rest.range(of: "*") {
                let before = rest[rest.startIndex..<openRange.lowerBound]
                if !before.isEmpty { result.append(AttributedString(before)) }
                let afterOpen = rest[openRange.upperBound...]
                if let closeRange = afterOpen.range(of: "*") {
                    var italic = AttributedString(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    italic.inlinePresentationIntent = .emphasized
                    result.append(italic)
                    rest = afterOpen[closeRange.upperBound...]
                } else {
                    result.append(AttributedString("*"))
                    rest = afterOpen
                }
            } else {
                result.append(AttributedString(rest))
                break
            }
        }
        return result
    }
}

// MARK: - Thinking indicator

struct AskThinkingView: View {
    private let text = Array("Thinking...")
    private let cycleDuration: Double = 1.5
    @State private var phase: Double = 0
    @State private var breathOpacity: Double = 1.0

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<text.count, id: \.self) { index in
                let position = Double(index) / Double(text.count)
                let distance = abs(position - phase)
                let wrapped = min(distance, 1.0 - distance)
                let glow = max(0, 1.0 - wrapped * 5.0)

                Text(String(text[index]))
                    .font(AskFont.caption)
                    .foregroundColor(
                        Color(
                            red: 0.7 + 0.3 * glow,
                            green: 0.25 * (1 - glow),
                            blue: 0.25 * (1 - glow)
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(breathOpacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                breathOpacity = 0.7
            }
        }
        .onReceive(timer) { _ in
            phase += 1.0 / 30.0 / cycleDuration
            if phase > 1.0 { phase -= 1.0 }
        }
    }
}

// MARK: - FiraCode Nerd Font helper

enum AskFont {
    static func regular(size: CGFloat) -> Font {
        .custom("FiraCodeNerdFontComplete-Regular", size: size)
    }

    static func semiBold(size: CGFloat) -> Font {
        .custom("FiraCodeNerdFontComplete-SemiBold", size: size)
    }

    static func bold(size: CGFloat) -> Font {
        .custom("FiraCodeNerdFontComplete-Bold", size: size)
    }

    static let body = regular(size: 13)
    static let caption = regular(size: 11)
    static let caption2 = regular(size: 10)
}

// MARK: - Models

struct AskConversationLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: Kind

    enum Kind {
        case user, assistant, tool, system, error
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

enum AskConversationSegment {
    case single(AskConversationLine)
    case toolGroup([AskConversationLine])

    var id: String {
        switch self {
        case .single(let line): line.id.uuidString
        case .toolGroup(let lines): lines.first?.id.uuidString ?? UUID().uuidString
        }
    }
}

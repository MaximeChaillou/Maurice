import SwiftUI

struct BubbleView: View {
    let text: String
    var style: Style = .final
    var timestamp: String?

    enum Style {
        case final
        case volatile
    }

    var body: some View {
        Text(text)
            .font(.body)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(style == .volatile ? .secondary : .primary)
            .modifier(BubbleBackgroundModifier(style: style))
            .help(timestamp ?? "")
    }
}

private struct BubbleBackgroundModifier: ViewModifier {
    let style: BubbleView.Style

    func body(content: Content) -> some View {
        switch style {
        case .final:
            content
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        case .volatile:
            content
                .background(.clear, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
    }
}

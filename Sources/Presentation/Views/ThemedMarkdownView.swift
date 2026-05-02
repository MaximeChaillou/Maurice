import SwiftUI

struct ThemedMarkdownView: View {
    @Binding var content: String
    var theme: MarkdownTheme

    var body: some View {
        MarkdownView(content: $content, theme: theme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

struct ClaudeMDView: View {
    var markdownTheme: MarkdownTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This file configures the AI assistant's behavior. It is read at each interaction.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            FolderFileDetailView(
                file: FolderFile(url: AppSettings.claudeMDURL),
                markdownTheme: markdownTheme
            )
        }
    }
}

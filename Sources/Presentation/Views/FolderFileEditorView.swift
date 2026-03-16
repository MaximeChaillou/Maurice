import SwiftUI

struct FolderFileDetailView: View {
    let file: FolderFile
    var markdownTheme: MarkdownTheme = MarkdownTheme()

    var body: some View {
        VStack(spacing: 0) {
            Text(file.name)
                .font(.headline)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)

            Divider()

            FolderFileEditorView(file: file, markdownTheme: markdownTheme)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FolderFileEditorView: View {
    let file: FolderFile
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @State private var bodyText: String = ""
    @State private var lastSaveDate = Date.distantPast
    @Environment(ErrorState.self) private var errorState: ErrorState?

    var body: some View {
        ThemedMarkdownView(content: $bodyText, theme: markdownTheme)
            .onAppear { loadFile() }
            .onChange(of: bodyText) {
                lastSaveDate = Date()
                let text = bodyText
                let url = file.url
                let errorState = errorState
                Task.detached {
                    do {
                        try text.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        await errorState?.show("Impossible de sauvegarder : \(error.localizedDescription)")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
                guard Date().timeIntervalSince(lastSaveDate) > 2.0 else { return }
                loadFile()
            }
    }

    private func loadFile() {
        let url = file.url
        Task {
            let text = await Task.detached {
                (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }.value
            if text != bodyText {
                bodyText = text
            }
        }
    }
}

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
    @State private var loadedText: String = ""
    @State private var lastSaveDate = Date.distantPast
    @State private var isLoaded = false
    @Environment(ErrorState.self) private var errorState: ErrorState?

    var body: some View {
        ThemedMarkdownView(content: $bodyText, theme: markdownTheme)
            .task(id: file.url) {
                let url = file.url
                let text = await Task.detached {
                    (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                }.value
                loadedText = text
                bodyText = text
                isLoaded = true
            }
            .onChange(of: bodyText) {
                guard isLoaded, bodyText != loadedText else { return }
                loadedText = bodyText
                lastSaveDate = Date()
                let text = bodyText
                let url = file.url
                let errorState = errorState
                Task.detached {
                    do {
                        try text.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        IssueLogger.log(.error, "Failed to save file", context: url.path, error: error)
                        await errorState?.show("Impossible de sauvegarder : \(error.localizedDescription)")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
                guard Date().timeIntervalSince(lastSaveDate) > 2.0 else { return }
                reloadFile()
            }
    }

    private func reloadFile() {
        let url = file.url
        Task {
            let text = await Task.detached {
                (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }.value
            if text != bodyText {
                loadedText = text
                bodyText = text
            }
        }
    }
}

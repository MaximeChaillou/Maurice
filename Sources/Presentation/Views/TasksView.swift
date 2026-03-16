import SwiftUI

struct TasksView: View {
    var markdownTheme: MarkdownTheme
    @State private var content: String = ""
    @State private var lastSaveDate = Date.distantPast
    @Environment(ErrorState.self) private var errorState: ErrorState?
    private let fileURL = AppSettings.tasksFileURL

    var body: some View {
        ThemedMarkdownView(content: $content, theme: markdownTheme)
            .onAppear { load() }
            .onChange(of: content) { save() }
            .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
                guard Date().timeIntervalSince(lastSaveDate) > 2.0 else { return }
                load()
            }
    }

    private func load() {
        let url = fileURL
        Task {
            let text = await Task.detached {
                (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }.value
            if text != content {
                content = text
            }
        }
    }

    private func save() {
        lastSaveDate = Date()
        let text = content
        let url = fileURL
        let errorState = errorState
        Task.detached {
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                await errorState?.show("Impossible de sauvegarder les tâches : \(error.localizedDescription)")
            }
        }
    }
}

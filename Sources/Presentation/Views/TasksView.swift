import SwiftUI

struct TasksView: View {
    var markdownTheme: MarkdownTheme
    @State private var content: String = ""
    @Environment(ErrorState.self) private var errorState: ErrorState?
    private let fileURL = AppSettings.tasksFileURL

    var body: some View {
        ThemedMarkdownView(content: $content, theme: markdownTheme)
            .onAppear { load() }
            .onChange(of: content) { save() }
            .onReceive(NotificationCenter.default.publisher(for: .skillRunnerDidFinish)) { _ in
                load()
            }
    }

    private func load() {
        let url = fileURL
        Task {
            let text = await Task.detached {
                (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }.value
            content = text
        }
    }

    private func save() {
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

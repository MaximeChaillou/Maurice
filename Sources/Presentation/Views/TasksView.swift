import SwiftUI

struct TasksView: View {
    var markdownTheme: MarkdownTheme
    @State private var content: String = ""
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
        content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    private func save() {
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

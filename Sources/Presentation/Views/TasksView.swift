import SwiftUI

struct TasksView: View {
    var markdownTheme: MarkdownTheme

    var body: some View {
        FolderFileEditorView(
            file: FolderFile(url: AppSettings.tasksFileURL),
            markdownTheme: markdownTheme
        )
    }
}

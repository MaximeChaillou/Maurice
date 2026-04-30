import SwiftUI

struct TasksView: View {
    var markdownTheme: MarkdownTheme

    var body: some View {
        TabContentCard {
            FolderFileEditorView(
                file: FolderFile(url: AppSettings.tasksFileURL),
                markdownTheme: markdownTheme
            )
        }
        .padding(14)
    }
}

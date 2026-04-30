import SwiftUI

// MARK: - Date Entry Content

struct DateEntryContentView: View {
    let entry: MeetingDateEntry
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @Binding var showTranscripts: Bool

    var body: some View {
        if showTranscripts, let file = entry.transcriptFile {
            TranscriptDetailView(url: file.url).id(file.id)
        } else if let file = entry.noteFile {
            FolderFileEditorView(file: file, markdownTheme: markdownTheme).id(file.id)
        } else if let file = entry.transcriptFile {
            TranscriptDetailView(url: file.url).id(file.id)
        }
    }
}

// MARK: - Generic Deletion Alert Modifier

struct DeletionAlertModifier<Item: Identifiable>: ViewModifier {
    let title: LocalizedStringKey
    @Binding var item: Item?
    let message: (Item) -> String
    let onDelete: (Item) -> Void

    func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: Binding(
                get: { item != nil },
                set: { if !$0 { item = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { item = nil }
            Button("Delete", role: .destructive) {
                if let toDelete = item {
                    onDelete(toDelete)
                    item = nil
                }
            }
        } message: {
            if let toDelete = item { Text(message(toDelete)) }
        }
    }
}

extension View {
    func deletionAlert<Item: Identifiable>(
        _ title: LocalizedStringKey,
        item: Binding<Item?>,
        message: @escaping (Item) -> String,
        onDelete: @escaping (Item) -> Void
    ) -> some View {
        modifier(DeletionAlertModifier(title: title, item: item, message: message, onDelete: onDelete))
    }
}

// MARK: - Entry Delete Alert Modifier

struct EntryDeleteAlertModifier: ViewModifier {
    @Binding var entryDeleteAction: EntryDeleteAction?
    let onDelete: (EntryDeleteAction) -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Delete?",
            isPresented: Binding(
                get: { entryDeleteAction != nil },
                set: { if !$0 { entryDeleteAction = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { entryDeleteAction = nil }
            Button("Delete", role: .destructive) {
                if let action = entryDeleteAction {
                    onDelete(action)
                    entryDeleteAction = nil
                }
            }
        } message: {
            if let action = entryDeleteAction { Text(action.message) }
        }
    }
}

extension View {
    func entryDeleteAlert(
        action: Binding<EntryDeleteAction?>,
        onDelete: @escaping (EntryDeleteAction) -> Void
    ) -> some View {
        modifier(EntryDeleteAlertModifier(entryDeleteAction: action, onDelete: onDelete))
    }
}

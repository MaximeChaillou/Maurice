import SwiftUI

struct SubfolderNavigationView: View {
    let files: [FolderFile]
    @Binding var index: Int
    @Binding var isAdding: Bool
    @Binding var newFileName: String
    let addLabel: LocalizedStringKey
    let emptyTitle: LocalizedStringKey
    let emptyIcon: String
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var consoleViewModel: ConsoleViewModel?
    var subfolderURL: URL?
    var onCreate: () -> Void
    var onDelete: (FolderFile) -> Void

    @State private var fileToDelete: FolderFile?
    @State private var showImport = false

    var body: some View {
        VStack(spacing: 0) {
            if files.isEmpty {
                emptyState
            } else {
                fileContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isAdding) {
            AddItemSheet(
                title: addLabel,
                placeholder: "Name (e.g. 2025-S2)",
                text: $newFileName,
                onCreate: { onCreate() },
                onCancel: { newFileName = "" }
            )
        }
        .deletionAlert(
            "Delete?",
            item: $fileToDelete,
            message: { String(localized: "'\($0.name)' will be permanently deleted.") },
            onDelete: { onDelete($0) }
        )
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            ContentUnavailableView(emptyTitle, systemImage: emptyIcon)
            Spacer()
            Divider()
            HStack(spacing: 8) {
                Button { isAdding = true } label: {
                    Label(addLabel, systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let console = consoleViewModel, let folderURL = subfolderURL {
                    Button { showImport = true } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .popover(isPresented: $showImport) {
                        ImportDocumentView(
                            targetPath: folderURL.appendingPathComponent("import.md").path,
                            consoleViewModel: console,
                            onDismiss: { showImport = false }
                        )
                    }
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        let safeIndex = min(index, files.count - 1)
        let file = files[max(safeIndex, 0)]

        header(for: file)
        Divider()
        FolderFileEditorView(file: file, markdownTheme: markdownTheme).id(file.id)
    }

    private func header(for file: FolderFile) -> some View {
        HStack {
            navigationButtons
            Spacer()
            Text(file.name).font(.headline)
            Spacer()
            actionButtons(for: file)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var navigationButtons: some View {
        HStack {
            Button {
                if index < files.count - 1 { index += 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(index >= files.count - 1)

            Button {
                if index > 0 { index -= 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(index <= 0)
        }
    }

    private func actionButtons(for file: FolderFile) -> some View {
        HStack {
            Button { isAdding = true } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)

            if let console = consoleViewModel, let folderURL = subfolderURL {
                Button { showImport = true } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .help("Import a file or link")
                .popover(isPresented: $showImport) {
                    ImportDocumentView(
                        targetPath: folderURL.appendingPathComponent("\(file.name).md").path,
                        consoleViewModel: console,
                        onDismiss: { showImport = false }
                    )
                }
            }

            Menu {
                Button(role: .destructive) { fileToDelete = file } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 32, height: 32)
        }
    }
}

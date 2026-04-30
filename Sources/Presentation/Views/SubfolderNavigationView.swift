import SwiftUI

struct SubfolderNavigationView: View {
    let files: [FolderFile]
    @Binding var index: Int
    @Binding var isAdding: Bool
    @Binding var newFileName: String
    let addLabel: LocalizedStringKey
    let emptyTitle: LocalizedStringKey
    let emptyDescription: LocalizedStringKey?
    let emptyIcon: String
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var consoleViewModel: ConsoleViewModel?
    var subfolderURL: URL?
    var leadingSegments: [BreadcrumbSegment] = []
    var onCreate: () -> Void
    var onDelete: (FolderFile) -> Void

    @State private var fileToDelete: FolderFile?

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
            if !leadingSegments.isEmpty {
                HStack(spacing: 8) {
                    BreadcrumbBar(segments: leadingSegments)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                Divider().opacity(0.5)
            }

            Spacer()
            if let emptyDescription {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: Text(emptyDescription)
                )
            } else {
                ContentUnavailableView(emptyTitle, systemImage: emptyIcon)
            }
            Spacer()
            Divider()
            HStack(spacing: 8) {
                Button { isAdding = true } label: {
                    Label(addLabel, systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let console = consoleViewModel, let folderURL = subfolderURL {
                    Button {
                        ImportDocumentHelper.pickFile(
                            targetPath: folderURL.appendingPathComponent("import.md").path,
                            consoleViewModel: console
                        )
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        let safeIndex = min(index, files.count - 1)
        let file = files[max(safeIndex, 0)]

        toolbar(for: file)
        Divider().opacity(0.5)
        FolderFileEditorView(file: file, markdownTheme: markdownTheme).id(file.id)
    }

    private func toolbar(for file: FolderFile) -> some View {
        HStack(spacing: 8) {
            BreadcrumbBar(segments: leadingSegments + [fileSegment(active: file)])
            Spacer(minLength: 8)
            actionButtons(for: file)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func fileSegment(active: FolderFile) -> BreadcrumbSegment {
        BreadcrumbSegment(
            id: "subfolder-file",
            label: "\(active.name).md",
            kind: .file,
            popoverTitle: String(localized: "Files"),
            emptyMessage: String(localized: "No other files"),
            groups: [BreadcrumbSiblingGroup(
                id: "all",
                title: nil,
                siblings: files.map { f in
                    BreadcrumbSibling(
                        id: f.url.path,
                        label: "\(f.name).md",
                        leading: .symbol("doc.text"),
                        active: f.url == active.url
                    )
                }
            )],
            onPick: { path in
                if let idx = files.firstIndex(where: { $0.url.path == path }) {
                    index = idx
                }
            }
        )
    }

    private func actionButtons(for file: FolderFile) -> some View {
        HStack(spacing: 6) {
            Button { isAdding = true } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(addLabel)

            if let console = consoleViewModel, let folderURL = subfolderURL {
                Button {
                    ImportDocumentHelper.pickFile(
                        targetPath: folderURL.appendingPathComponent("\(file.name).md").path,
                        consoleViewModel: console
                    )
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Import a file or link")
            }

            Menu {
                Button(role: .destructive) { fileToDelete = file } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
        }
    }
}

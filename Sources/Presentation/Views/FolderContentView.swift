import SwiftUI

struct FolderContentView: View {
    let emptyIcon: String
    let emptyTitle: String
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var navigateByDate: Bool = false
    var showSkillConfig: Bool = false
    var recordingViewModel: RecordingViewModel?
    var skillRunner: SkillRunner?

    @State var viewModel: FolderContentViewModel

    @State private var showConfigSidebar: Bool = false
    @State private var folderToDelete: FolderItem?
    @State private var entryDeleteAction: EntryDeleteAction?
    @State private var showTranscripts = false

    var body: some View {
        HStack(spacing: 0) {
            folderList
                .frame(width: 240)

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showConfigSidebar) {
            if let folder = viewModel.currentFolder,
               let runner = skillRunner {
                MeetingConfigSheet(
                    folderName: folder.name,
                    folderURL: folder.url,
                    config: $viewModel.meetingConfig,
                    runner: runner,
                    onRename: { newName in
                        viewModel.renameFolder(folder, to: newName)
                    }
                )
                .frame(width: 400, height: 500)
                .onDisappear {
                    viewModel.updateCurrentFolderIcon(viewModel.meetingConfig.icon)
                }
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .onAppear { viewModel.loadFolders() }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
            viewModel.loadFolders()
            if let folder = viewModel.currentFolder {
                viewModel.selectFileAtIndex(in: folder)
            }
        }
    }

    // MARK: - Folder list (left)

    private var folderList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Réunions")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isAddingFolder = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Nouvelle réunion")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(selection: $viewModel.selectedFolder) {
                ForEach(viewModel.folders) { folder in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            if let icon = folder.icon {
                                Text(icon)
                            }
                            Text(folder.name)
                                .lineLimit(1)
                        }
                        .font(.body)
                        Text("\(folder.fileCount) fichier\(folder.fileCount > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(folder.name)
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        if showSkillConfig {
                            Button {
                                viewModel.selectedFolder = folder.name
                                let url = folder.url
                                Task {
                                    let cfg = await Task.detached {
                                        MeetingConfig.load(from: url)
                                    }.value
                                    viewModel.meetingConfig = cfg
                                    showConfigSidebar = true
                                }
                            } label: {
                                Label("Configurer", systemImage: "gearshape")
                            }
                            Divider()
                        }
                        Button(role: .destructive) {
                            folderToDelete = folder
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            folderToDelete = folder
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .deletionAlert(
                "Supprimer le dossier ?",
                item: $folderToDelete,
                message: { "Le dossier « \($0.name) » et tout son contenu seront supprimés définitivement." },
                onDelete: { viewModel.deleteFolder($0) }
            )
            .onChange(of: viewModel.selectedFolder) {
                viewModel.selectedFile = nil
                recordingViewModel?.subdirectory = viewModel.selectedFolder
                if let folder = viewModel.currentFolder {
                    let url = folder.url
                    Task {
                        let config = await Task.detached {
                            MeetingConfig.load(from: url)
                        }.value
                        viewModel.meetingConfig = config
                    }
                    if navigateByDate {
                        viewModel.fileIndex = 0
                        viewModel.selectFileAtIndex(in: folder)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isAddingFolder) {
            AddItemSheet(
                title: "Nouvelle réunion",
                placeholder: "Nom de la réunion",
                text: $viewModel.newFolderName,
                onCreate: { viewModel.createFolder() },
                onCancel: { viewModel.isAddingFolder = false; viewModel.newFolderName = "" }
            )
        }
    }

    // MARK: - Right pane

    @ViewBuilder
    private var detailPane: some View {
        if let folder = viewModel.currentFolder {
            if navigateByDate, !folder.dateEntries.isEmpty {
                dateNavigationDetail(for: folder)
            } else if folder.files.count == 1, let file = folder.files.first {
                FolderFileDetailView(file: file, markdownTheme: markdownTheme)
                    .id(file.id)
            } else {
                fileListDetail(for: folder)
            }
        } else if viewModel.folders.isEmpty {
            ContentUnavailableView(
                "Aucune réunion",
                systemImage: "calendar",
                description: Text("Cliquez sur + pour créer votre première réunion récurrente (ex : standup, 1-1).")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptyIcon,
                description: Text("Sélectionnez un élément dans la liste.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
// MARK: - Date navigation
extension FolderContentView {
    func dateNavigationDetail(for folder: FolderItem) -> some View {
        let entries = folder.dateEntries
        let safeIndex = min(viewModel.fileIndex, entries.count - 1)
        let entry = entries[max(safeIndex, 0)]

        return VStack(spacing: 0) {
            DateNavigationHeader(
                entry: entry,
                totalEntries: entries.count,
                index: $viewModel.fileIndex,
                showTranscripts: $showTranscripts,
                config: showSkillConfig ? viewModel.meetingConfig : nil,
                skillRunner: skillRunner,
                showConfigAction: showSkillConfig ? { showConfigSidebar = true } : nil,
                entryDeleteAction: $entryDeleteAction,
                nextFileURL: folder.url.appendingPathComponent("next.md")
            )
            Divider()
            DateEntryContentView(
                entry: entry, markdownTheme: markdownTheme, showTranscripts: $showTranscripts
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.fileIndex) { showTranscripts = false }
        .entryDeleteAlert(action: $entryDeleteAction) { action in
            switch action {
            case .note(let e): viewModel.deleteDateEntry(e, noteOnly: true)
            case .transcript(let e): viewModel.deleteDateEntry(e, transcriptOnly: true)
            case .both(let e): viewModel.deleteDateEntry(e)
            }
        }
    }
}

// MARK: - File list
extension FolderContentView {
    func fileListDetail(for folder: FolderItem) -> some View {
        HStack(spacing: 0) {
            fileList(for: folder)
                .frame(width: 220)

            Divider()

            if let url = viewModel.selectedFile,
               let file = folder.files.first(where: { $0.url == url }) {
                FolderFileDetailView(file: file, markdownTheme: markdownTheme)
                    .id(file.id)
            } else {
                ContentUnavailableView(
                    "Aucun fichier sélectionné",
                    systemImage: "doc.text",
                    description: Text("Sélectionnez un fichier dans la liste.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func fileList(for folder: FolderItem) -> some View {
        List(selection: $viewModel.selectedFile) {
            ForEach(folder.files) { file in
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(file.date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .tag(file.url)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

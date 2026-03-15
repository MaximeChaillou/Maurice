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
                MeetingConfigSidebar(
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
        .onChange(of: skillRunner?.isRunning) {
            if skillRunner?.isRunning == false {
                viewModel.loadFolders()
                if let folder = viewModel.currentFolder {
                    viewModel.selectFileAtIndex(in: folder)
                }
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
            .alert(
                "Supprimer le dossier ?",
                isPresented: Binding(
                    get: { folderToDelete != nil },
                    set: { if !$0 { folderToDelete = nil } }
                )
            ) {
                Button("Annuler", role: .cancel) { folderToDelete = nil }
                Button("Supprimer", role: .destructive) {
                    if let folder = folderToDelete {
                        viewModel.deleteFolder(folder)
                        folderToDelete = nil
                    }
                }
            } message: {
                if let folder = folderToDelete {
                    Text("Le dossier « \(folder.name) » et tout son contenu seront supprimés définitivement.")
                }
            }
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
            dateNavigationHeader(entry: entry, totalEntries: entries.count)
            Divider()

            if showTranscripts, let transcript = entry.transcript {
                TranscriptDetailView(transcript: transcript)
                    .id(transcript.id)
            } else if let file = entry.noteFile {
                FolderFileEditorView(file: file, markdownTheme: markdownTheme)
                    .id(file.id)
            } else if let transcript = entry.transcript {
                TranscriptDetailView(transcript: transcript)
                    .id(transcript.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.fileIndex) { showTranscripts = false }
        .alert(
            "Supprimer ?",
            isPresented: Binding(
                get: { entryDeleteAction != nil },
                set: { if !$0 { entryDeleteAction = nil } }
            )
        ) {
            Button("Annuler", role: .cancel) { entryDeleteAction = nil }
            Button("Supprimer", role: .destructive) {
                if let action = entryDeleteAction {
                    performEntryDelete(action)
                    entryDeleteAction = nil
                }
            }
        } message: {
            if let action = entryDeleteAction { Text(action.message) }
        }
    }

    private func performEntryDelete(_ action: EntryDeleteAction) {
        switch action {
        case .note(let e): viewModel.deleteDateEntry(e, noteOnly: true)
        case .transcript(let e): viewModel.deleteDateEntry(e, transcriptOnly: true)
        case .both(let e): viewModel.deleteDateEntry(e)
        }
    }

    func dateNavigationHeader(entry: MeetingDateEntry, totalEntries: Int) -> some View {
        VStack(spacing: 4) {
            // Line 1: Navigation
            HStack {
                Button {
                    if viewModel.fileIndex < totalEntries - 1 { viewModel.fileIndex += 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .interactiveHover()
                .disabled(viewModel.fileIndex >= totalEntries - 1)

                Spacer()

                Text(entry.date, format: .dateTime.day().month(.wide).year())
                    .font(.headline)

                Spacer()

                Button {
                    if viewModel.fileIndex > 0 { viewModel.fileIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .interactiveHover()
                .disabled(viewModel.fileIndex <= 0)
            }

            // Line 2: Actions
            HStack(spacing: 8) {
                Spacer()
                if navigateByDate { transcriptToggleButton(for: entry) }
                if showSkillConfig, skillRunner != nil {
                    runActionsMenu
                    configToggleButton
                }
                entryActionsMenu(for: entry)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func entryActionsMenu(for entry: MeetingDateEntry) -> some View {
        Menu {
            if entry.hasNote {
                Button(role: .destructive) {
                    entryDeleteAction = .note(entry)
                } label: {
                    Label("Supprimer la note", systemImage: "doc.text")
                }
            }
            if entry.hasTranscript {
                Button(role: .destructive) {
                    entryDeleteAction = .transcript(entry)
                } label: {
                    Label("Supprimer le transcript", systemImage: "waveform")
                }
            }
            if entry.hasNote && entry.hasTranscript {
                Divider()
                Button(role: .destructive) {
                    entryDeleteAction = .both(entry)
                } label: {
                    Label("Tout supprimer", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 32, height: 32)
        .interactiveHover()
    }
}

// MARK: - File list & toggles
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

    func transcriptToggleButton(for entry: MeetingDateEntry) -> some View {
        let canToggle = entry.hasNote && entry.hasTranscript
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTranscripts.toggle()
            }
        } label: {
            Image(systemName: showTranscripts ? "doc.text" : "waveform")
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .opacity(canToggle ? 1.0 : 0.3)
        }
        .buttonStyle(.plain)
        .interactiveHover()
        .disabled(!canToggle)
        .help(
            !canToggle
                ? (entry.hasNote ? "Pas de transcript" : "Pas de note")
                : (showTranscripts ? "Afficher les notes" : "Afficher les transcripts")
        )
    }

    @ViewBuilder
    var runActionsMenu: some View {
        let actions = viewModel.meetingConfig.actions
        if let runner = skillRunner, !actions.isEmpty {
            Menu {
                ForEach(actions) { action in
                    Button {
                        guard !runner.isRunning else { return }
                        runner.actionID = action.id
                        runner.run(
                            skillFilename: action.skillFilename,
                            buttonName: action.buttonName,
                            parameter: action.parameter,
                            workingDirectory: AppSettings.rootDirectory
                        )
                    } label: {
                        Label(action.buttonName, systemImage: "play.fill")
                    }
                    .disabled(runner.isRunning)
                }
            } label: {
                ZStack {
                    if let runner = skillRunner, runner.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.body)
                    }
                }
                .frame(width: 32, height: 32)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 32, height: 32)
            .interactiveHover()
            .help("Lancer une action")
        }
    }

    var configToggleButton: some View {
        Button {
            showConfigSidebar = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .interactiveHover()
        .help("Configurer les skills")
    }
}

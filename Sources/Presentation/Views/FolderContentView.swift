import SwiftUI

struct FolderContentView: View {
    let emptyIcon: String
    let emptyTitle: LocalizedStringKey
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var navigateByDate: Bool = false
    var showSkillConfig: Bool = false
    var recordingViewModel: RecordingViewModel?
    var consoleViewModel: ConsoleViewModel?

    @State var viewModel: FolderContentViewModel

    @State private var showConfigSidebar: Bool = false
    @State private var showAddActionForm: Bool = false
    @State private var folderToDelete: FolderItem?
    @State private var moveDestinations: [MoveDestination] = []
    @State private var entryDeleteAction: EntryDeleteAction?
    @State private var showTranscripts = false
    @State private var addActionName = ""
    @State private var addActionSkill: String?
    @State private var addActionParameter = ""
    @State private var addActionAvailableSkills: [SkillFile] = []

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
               let console = consoleViewModel {
                MeetingConfigSheet(
                    folderName: folder.name,
                    folderURL: folder.url,
                    config: $viewModel.meetingConfig,
                    consoleViewModel: console,
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
        .sheet(isPresented: $showAddActionForm) {
            ActionFormSheet(
                name: $addActionName,
                skill: $addActionSkill,
                parameter: $addActionParameter,
                availableSkills: addActionAvailableSkills,
                onCancel: { showAddActionForm = false },
                onSave: { action in
                    viewModel.meetingConfig.addAction(action)
                    if let folder = viewModel.currentFolder {
                        viewModel.meetingConfig.saveAsync(to: folder.url)
                    }
                    showAddActionForm = false
                }
            )
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .onAppear { viewModel.loadFolders() }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { notif in
            guard notif.affectsPath(viewModel.directory) else { return }
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
                Text("Meetings")
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
                .help("New meeting")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.folders) { folder in
                        Button {
                            viewModel.selectedFolder = folder.name
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    if let icon = folder.icon {
                                        Text(icon)
                                    }
                                    Text(folder.name)
                                        .lineLimit(1)
                                }
                                .font(.body)
                                Text("\(folder.fileCount) files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                            .background(
                                viewModel.selectedFolder == folder.name
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear,
                                in: .rect(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if showSkillConfig {
                                Button {
                                    viewModel.selectedFolder = folder.name
                                    let url = folder.url
                                    let folderName = folder.name
                                    Task {
                                        await viewModel.loadMeetingConfig(for: folderName, from: url)
                                        guard viewModel.selectedFolder == folderName else { return }
                                        showConfigSidebar = true
                                    }
                                } label: {
                                    Label("Configure", systemImage: "gearshape")
                                }
                                Divider()
                            }
                            moveMenu(for: folder)
                            Divider()
                            Button(role: .destructive) {
                                folderToDelete = folder
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .deletionAlert(
                "Delete folder?",
                item: $folderToDelete,
                message: { String(localized: "The folder '\($0.name)' and all its content will be permanently deleted.") },
                onDelete: { viewModel.deleteFolder($0) }
            )
            .onChange(of: viewModel.selectedFolder) {
                viewModel.selectedFile = nil
                recordingViewModel?.subdirectory = viewModel.selectedFolder
                if let folder = viewModel.currentFolder {
                    let url = folder.url
                    let folderName = folder.name
                    Task {
                        await viewModel.loadMeetingConfig(for: folderName, from: url)
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
                title: "New meeting",
                placeholder: "Meeting name",
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
                "No meetings",
                systemImage: "calendar",
                description: Text("Click + to create your first recurring meeting (e.g. standup, 1-1).")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptyIcon,
                description: Text("Select an item from the list.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
// MARK: - Move menu

extension FolderContentView {
    @ViewBuilder
    func moveMenu(for folder: FolderItem) -> some View {
        let destinations = FolderContentViewModel.listMoveDestinations(excluding: folder)
        let sections = Dictionary(grouping: destinations, by: \.section)
        let sortedKeys = sections.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if destinations.isEmpty {
            Button {} label: {
                Label("Move content to…", systemImage: "folder.badge.arrow.right")
            }
            .disabled(true)
        } else {
            Menu {
                ForEach(sortedKeys, id: \.self) { section in
                    Section(section) {
                        if let items = sections[section] {
                            ForEach(items) { dest in
                                Button {
                                    viewModel.moveFolderContent(folder, to: dest.url)
                                } label: {
                                    Text(dest.name)
                                }
                            }
                        }
                    }
                }
            } label: {
                Label("Move content to…", systemImage: "folder.badge.arrow.right")
            }
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
                consoleViewModel: consoleViewModel,
                showConfigAction: showSkillConfig ? { showConfigSidebar = true } : nil,
                onAddAction: showSkillConfig ? {
                    addActionName = ""
                    addActionSkill = nil
                    addActionParameter = ""
                    Task {
                        addActionAvailableSkills = await MeetingSkillConfig.availableSkillsAsync()
                    }
                    showAddActionForm = true
                } : nil,
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
                    "No file selected",
                    systemImage: "doc.text",
                    description: Text("Select a file from the list.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func fileList(for folder: FolderItem) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(folder.files) { file in
                    Button {
                        viewModel.selectedFile = file.url
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.body)
                                .lineLimit(1)
                            Text(file.date, format: .dateTime.day().month(.abbreviated).year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                        .background(
                            viewModel.selectedFile == file.url
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear,
                            in: .rect(cornerRadius: 6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

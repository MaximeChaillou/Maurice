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
    @State private var folderToRename: FolderItem?
    @State private var renameText = ""
    @State private var folderToLink: FolderItem?
    @State private var entryDeleteAction: EntryDeleteAction?
    @State private var showTranscripts = false

    var body: some View {
        HStack(spacing: 0) {
            folderList
                .frame(width: 240)

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showConfigSidebar,
               let folder = viewModel.currentFolder,
               let runner = skillRunner {
                Divider()
                MeetingConfigSidebar(
                    folderName: folder.name,
                    folderURL: folder.url,
                    config: $viewModel.meetingConfig,
                    runner: runner,
                    onRename: { newName in
                        viewModel.renameFolder(folder, to: newName)
                    }
                )
                .frame(width: 320)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showConfigSidebar)
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
            List(selection: $viewModel.selectedFolder) {
                ForEach(viewModel.folders) { folder in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            if let icon = MeetingConfig.load(from: folder.url).icon {
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
                        Button {
                            renameText = folder.name
                            folderToRename = folder
                        } label: {
                            Label("Renommer", systemImage: "pencil")
                        }
                        Button {
                            folderToLink = folder
                        } label: {
                            Label("Lier un événement Calendar", systemImage: "calendar.badge.plus")
                        }
                        Divider()
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
            .alert(
                "Renommer la réunion",
                isPresented: Binding(
                    get: { folderToRename != nil },
                    set: { if !$0 { folderToRename = nil } }
                )
            ) {
                TextField("Nouveau nom", text: $renameText)
                Button("Annuler", role: .cancel) { folderToRename = nil }
                Button("Renommer") {
                    if let folder = folderToRename {
                        viewModel.renameFolder(folder, to: renameText)
                        folderToRename = nil
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { folderToLink != nil },
                set: { if !$0 { folderToLink = nil } }
            )) {
                if let folder = folderToLink {
                    CalendarLinkSheet(folder: folder) {
                        folderToLink = nil
                    }
                }
            }
            .onChange(of: viewModel.selectedFolder) {
                viewModel.selectedFile = nil
                recordingViewModel?.subdirectory = viewModel.selectedFolder
                if let folder = viewModel.currentFolder {
                    viewModel.meetingConfig = MeetingConfig.load(from: folder.url)
                    if navigateByDate {
                        viewModel.fileIndex = 0
                        viewModel.selectFileAtIndex(in: folder)
                    }
                }
            }

            Divider()

            if viewModel.isAddingFolder {
                HStack(spacing: 8) {
                    TextField("Nom de la réunion", text: $viewModel.newFolderName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.createFolder() }
                        .onExitCommand { viewModel.isAddingFolder = false; viewModel.newFolderName = "" }
                    Button("OK") { viewModel.createFolder() }
                        .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Annuler", role: .cancel) { viewModel.isAddingFolder = false; viewModel.newFolderName = "" }
                }
                .padding(8)
            } else {
                Button {
                    viewModel.isAddingFolder = true
                } label: {
                    Label("Nouvelle réunion", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(8)
            }
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
            .disabled(viewModel.fileIndex <= 0)

            if navigateByDate { transcriptToggleButton(for: entry) }
            if showSkillConfig, skillRunner != nil { configToggleButton }
            entryActionsMenu(for: entry)
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
        .glassEffect(.regular.interactive(), in: .circle)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 32, height: 32)
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
                .glassEffect(.regular.interactive(), in: .circle)
                .opacity(canToggle ? 1.0 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!canToggle)
        .help(
            !canToggle
                ? (entry.hasNote ? "Pas de transcript" : "Pas de note")
                : (showTranscripts ? "Afficher les notes" : "Afficher les transcripts")
        )
    }

    var configToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showConfigSidebar.toggle()
            }
        } label: {
            Image(systemName: showConfigSidebar ? "sidebar.trailing" : "gearshape")
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .help("Configurer les skills")
    }
}

// MARK: - Models
struct FolderItem: Identifiable {
    let name: String, url: URL, files: [FolderFile]
    var dateEntries: [MeetingDateEntry] = []
    var id: String { name }
    var fileCount: Int { max(files.count, dateEntries.count) }
}
enum EntryDeleteAction {
    case note(MeetingDateEntry)
    case transcript(MeetingDateEntry)
    case both(MeetingDateEntry)

    var entry: MeetingDateEntry {
        switch self {
        case .note(let e), .transcript(let e), .both(let e): e
        }
    }

    var message: String {
        switch self {
        case .note: "La note du \(entry.dateString) sera supprimée définitivement."
        case .transcript: "Le transcript du \(entry.dateString) sera supprimé définitivement."
        case .both: "La note et le transcript du \(entry.dateString) seront supprimés définitivement."
        }
    }
}
struct MeetingDateEntry: Identifiable {
    let dateString: String
    let date: Date
    let noteFile: FolderFile?
    let transcript: StoredTranscript?
    var id: String { dateString }
    var hasNote: Bool { noteFile != nil }
    var hasTranscript: Bool { transcript != nil }
}
struct FolderFile: Identifiable, Hashable {
    let id: URL, name: String, date: Date, url: URL
    var content: String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    func save(content: String) { try? content.write(to: url, atomically: true, encoding: .utf8) }
}

private struct FolderFileDetailView: View {
    let file: FolderFile
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @State private var bodyText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Text(file.name)
                .font(.headline)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)

            Divider()

            FolderFileEditorView(file: file, markdownTheme: markdownTheme)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FolderFileEditorView: View {
    let file: FolderFile
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @State private var bodyText: String = ""

    var body: some View {
        ThemedMarkdownView(content: $bodyText, theme: markdownTheme)
            .onAppear { bodyText = file.content }
            .onChange(of: bodyText) { file.save(content: bodyText) }
    }
}

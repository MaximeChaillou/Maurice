import SwiftUI

struct PersonDetailView: View {
    let personName: String
    let personURL: URL
    let activeSection: PersonSection
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var recordingViewModel: RecordingViewModel?
    var consoleViewModel: ConsoleViewModel?

    @State private var assessmentFiles: [FolderFile] = []
    @State private var objectifsFiles: [FolderFile] = []
    @State private var assessmentIndex: Int = 0
    @State private var objectifIndex: Int = 0
    @State private var isAddingAssessment = false
    @State private var isAddingObjectif = false
    @State private var newFileName = ""
    @Environment(ErrorState.self) private var errorState: ErrorState?

    var body: some View {
        sectionContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { loadSubfolders() }
            .onChange(of: activeSection) { loadSubfolders() }
            .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { notif in
                guard notif.affectsPath(personURL) else { return }
                loadSubfolders()
            }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch activeSection {
        case .profile:
            markdownFileEditor(fileName: "profile.md")
        case .jobDescription:
            jobDescriptionSection
        case .oneOnOne:
            PersonOneOnOneView(
                personURL: personURL,
                markdownTheme: markdownTheme,
                consoleViewModel: consoleViewModel
            )
        case .assessment:
            SubfolderNavigationView(
                files: assessmentFiles, index: $assessmentIndex,
                isAdding: $isAddingAssessment, newFileName: $newFileName,
                addLabel: "New assessment", emptyTitle: "No assessments",
                emptyDescription: "Import a PDF to add it as a Markdown file.",
                emptyIcon: "checkmark.seal", markdownTheme: markdownTheme,
                consoleViewModel: consoleViewModel,
                subfolderURL: personURL.appendingPathComponent("assessment", isDirectory: true),
                onCreate: { createSubfolderFile(subfolder: "assessment", isAdding: $isAddingAssessment) },
                onDelete: { deleteSubfolderFile($0, subfolder: "assessment") }
            )
        case .objectifs:
            SubfolderNavigationView(
                files: objectifsFiles, index: $objectifIndex,
                isAdding: $isAddingObjectif, newFileName: $newFileName,
                addLabel: "New goal", emptyTitle: "No goals",
                emptyDescription: "Import a PDF to add it as a Markdown file.",
                emptyIcon: "target", markdownTheme: markdownTheme,
                consoleViewModel: consoleViewModel,
                subfolderURL: personURL.appendingPathComponent("objectifs", isDirectory: true),
                onCreate: { createSubfolderFile(subfolder: "objectifs", isAdding: $isAddingObjectif) },
                onDelete: { deleteSubfolderFile($0, subfolder: "objectifs") }
            )
        }
    }

    // MARK: - Job description with import

    @ViewBuilder
    private var jobDescriptionSection: some View {
        let fileURL = personURL.appendingPathComponent("job-description.md")
        let file = FolderFile(
            id: fileURL,
            name: fileURL.deletingPathExtension().lastPathComponent,
            date: (try? FileManager.default.attributesOfItem(
                atPath: fileURL.path
            )[.modificationDate] as? Date) ?? Date(),
            url: fileURL
        )
        VStack(spacing: 0) {
            if let console = consoleViewModel {
                HStack {
                    Spacer()
                    Button {
                        ImportDocumentHelper.pickFile(
                            targetPath: fileURL.path,
                            consoleViewModel: console
                        )
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .help("Import a file or link")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()
            }

            FolderFileEditorView(file: file, markdownTheme: markdownTheme)
        }
        .id("job-description.md")
    }

    // MARK: - Markdown file editor

    private func markdownFileEditor(fileName: String) -> some View {
        let fileURL = personURL.appendingPathComponent(fileName)
        let file = FolderFile(
            id: fileURL,
            name: fileURL.deletingPathExtension().lastPathComponent,
            date: (try? FileManager.default.attributesOfItem(
                atPath: fileURL.path
            )[.modificationDate] as? Date) ?? Date(),
            url: fileURL
        )
        return FolderFileEditorView(file: file, markdownTheme: markdownTheme)
            .id(fileName)
    }

    // MARK: - File operations

    private func loadSubfolders() {
        let url = personURL
        let section = activeSection
        Task {
            switch section {
            case .assessment:
                assessmentFiles = await Self.scanSubfolder("assessment", in: url)
            case .objectifs:
                objectifsFiles = await Self.scanSubfolder("objectifs", in: url)
            case .profile, .jobDescription, .oneOnOne:
                break
            }
        }
    }

    private static func scanSubfolder(_ name: String, in personURL: URL) async -> [FolderFile] {
        let dir = personURL.appendingPathComponent(name, isDirectory: true)
        return await Task.detached {
            DirectoryScanner.scan(at: dir, fileExtension: "md").files
                .map {
                    FolderFile(
                        id: $0.url,
                        name: $0.url.deletingPathExtension().lastPathComponent,
                        date: $0.date, url: $0.url
                    )
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        }.value
    }

    private func createSubfolderFile(subfolder: String, isAdding: Binding<Bool>) {
        let name = newFileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let dir = personURL.appendingPathComponent(subfolder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            IssueLogger.log(.error, "Failed to create subfolder directory", context: dir.path, error: error)
        }
        let fileURL = dir.appendingPathComponent("\(name).md")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        newFileName = ""
        isAdding.wrappedValue = false
        loadSubfolders()
        if subfolder == "assessment" {
            assessmentIndex = 0
        } else {
            objectifIndex = 0
        }
    }

    private func deleteSubfolderFile(_ file: FolderFile, subfolder: String) {
        do {
            try FileManager.default.removeItem(at: file.url)
        } catch {
            IssueLogger.log(.error, "Failed to delete subfolder file", context: file.url.path, error: error)
            errorState?.show(String(localized: "Unable to delete '\(file.name)': \(error.localizedDescription)"))
        }
        loadSubfolders()
        if subfolder == "assessment" {
            assessmentIndex = min(assessmentIndex, max(assessmentFiles.count - 1, 0))
        } else {
            objectifIndex = min(objectifIndex, max(objectifsFiles.count - 1, 0))
        }
    }
}

// MARK: - 1-1 View

struct PersonOneOnOneView: View {
    let personURL: URL
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var consoleViewModel: ConsoleViewModel?

    @State private var entries: [MeetingDateEntry] = []
    @State private var meetingConfig = MeetingConfig()
    @State private var index: Int = 0
    @State private var showTranscripts = false
    @State private var showConfigSheet = false
    @State private var showAddActionForm = false
    @State private var entryDeleteAction: EntryDeleteAction?
    @State private var addActionName = ""
    @State private var addActionSkill: String?
    @State private var addActionParameter = ""
    @State private var addActionAvailableSkills: [SkillFile] = []
    @Environment(ErrorState.self) private var errorState: ErrorState?

    private var oneOnOneDir: URL {
        personURL.appendingPathComponent("1-1", isDirectory: true)
    }

    var body: some View {
        dateNavigationDetail
        .onAppear { loadEntries(); loadConfig() }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { notif in
            guard notif.affectsPath(oneOnOneDir) else { return }
            loadEntries()
        }
        .sheet(isPresented: $showConfigSheet) {
            if let console = consoleViewModel {
                MeetingConfigSheet(
                    folderName: "1-1",
                    folderURL: oneOnOneDir,
                    config: $meetingConfig,
                    consoleViewModel: console
                )
                .frame(width: 400, height: 500)
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
                    meetingConfig.addAction(action)
                    meetingConfig.saveAsync(to: oneOnOneDir)
                    showAddActionForm = false
                }
            )
        }
    }

    // MARK: - Data loading

    private func loadEntries() {
        let dir = oneOnOneDir
        Task {
            entries = await MeetingDateEntry.scan(in: dir)
        }
    }

    private func loadConfig() {
        let dir = oneOnOneDir
        Task {
            meetingConfig = await Task.detached { MeetingConfig.load(from: dir) }.value
        }
    }

    // MARK: - Date navigation

    private var currentEntry: MeetingDateEntry? {
        guard !entries.isEmpty else { return nil }
        let safeIndex = min(index, entries.count - 1)
        return entries[max(safeIndex, 0)]
    }

    private var dateNavigationDetail: some View {
        VStack(spacing: 0) {
            DateNavigationHeader(
                entry: currentEntry,
                totalEntries: entries.count,
                index: $index,
                showTranscripts: $showTranscripts,
                config: meetingConfig,
                consoleViewModel: consoleViewModel,
                showConfigAction: consoleViewModel != nil ? { showConfigSheet = true } : nil,
                onAddAction: consoleViewModel != nil ? {
                    addActionName = ""
                    addActionSkill = nil
                    addActionParameter = ""
                    Task {
                        addActionAvailableSkills = await MeetingSkillConfig.availableSkillsAsync()
                    }
                    showAddActionForm = true
                } : nil,
                entryDeleteAction: $entryDeleteAction,
                nextFileURL: oneOnOneDir.appendingPathComponent("next.md")
            )
            Divider()
            if let entry = currentEntry {
                DateEntryContentView(
                    entry: entry, markdownTheme: markdownTheme, showTranscripts: $showTranscripts
                )
            } else {
                ContentUnavailableView(
                    "No 1-1s",
                    systemImage: "person.2",
                    description: Text("Start a recording to create a 1-1.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: index) { showTranscripts = false }
        .entryDeleteAlert(action: $entryDeleteAction) { [errorState] action in
            let entry = action.entry
            do {
                switch action {
                case .note:
                    if let note = entry.noteFile { try FileManager.default.removeItem(at: note.url) }
                case .transcript:
                    if let t = entry.transcript { try FileManager.default.removeItem(at: t.url) }
                case .both:
                    if let note = entry.noteFile { try FileManager.default.removeItem(at: note.url) }
                    if let t = entry.transcript { try FileManager.default.removeItem(at: t.url) }
                }
            } catch {
                IssueLogger.log(.error, "Failed to delete person entry", error: error)
                errorState?.show(String(localized: "Unable to delete: \(error.localizedDescription)"))
            }
            loadEntries()
        }
    }
}

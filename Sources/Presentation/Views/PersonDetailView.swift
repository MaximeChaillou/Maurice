import SwiftUI

struct PersonDetailView: View {
    let personName: String
    let personURL: URL
    let activeSection: PersonSection
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var recordingViewModel: RecordingViewModel?
    var skillRunner: SkillRunner?

    @State private var assessmentFiles: [FolderFile] = []
    @State private var objectifsFiles: [FolderFile] = []
    @State private var assessmentIndex: Int = 0
    @State private var objectifIndex: Int = 0
    @State private var isAddingAssessment = false
    @State private var isAddingObjectif = false
    @State private var newFileName = ""
    @State private var showImportJobDesc = false
    @State private var showImportAssessment = false
    @State private var showImportObjectif = false
    @Environment(ErrorState.self) private var errorState: ErrorState?

    var body: some View {
        sectionContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { loadSubfolders() }
            .onChange(of: activeSection) { loadSubfolders() }
            .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
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
                skillRunner: skillRunner
            )
        case .assessment:
            SubfolderNavigationView(
                files: assessmentFiles, index: $assessmentIndex,
                isAdding: $isAddingAssessment, newFileName: $newFileName,
                addLabel: "New assessment", emptyTitle: "No assessments",
                emptyIcon: "checkmark.seal", markdownTheme: markdownTheme,
                skillRunner: skillRunner,
                subfolderURL: personURL.appendingPathComponent("assessment", isDirectory: true),
                onCreate: { createSubfolderFile(subfolder: "assessment", isAdding: $isAddingAssessment) },
                onDelete: { deleteSubfolderFile($0, subfolder: "assessment") }
            )
        case .objectifs:
            SubfolderNavigationView(
                files: objectifsFiles, index: $objectifIndex,
                isAdding: $isAddingObjectif, newFileName: $newFileName,
                addLabel: "New goal", emptyTitle: "No goals",
                emptyIcon: "target", markdownTheme: markdownTheme,
                skillRunner: skillRunner,
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
            if let runner = skillRunner {
                HStack {
                    Spacer()
                    Button {
                        showImportJobDesc = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .help("Import a file or link")
                    .popover(isPresented: $showImportJobDesc) {
                        ImportDocumentView(
                            targetPath: fileURL.path,
                            runner: runner,
                            onDismiss: { showImportJobDesc = false }
                        )
                    }
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
        Task {
            let evals = await Self.scanSubfolder("assessment", in: url)
            let objs = await Self.scanSubfolder("objectifs", in: url)
            assessmentFiles = evals
            objectifsFiles = objs
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
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
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
    var skillRunner: SkillRunner?

    @State private var entries: [MeetingDateEntry] = []
    @State private var meetingConfig = MeetingConfig()
    @State private var index: Int = 0
    @State private var showTranscripts = false
    @State private var showConfigSheet = false
    @State private var entryDeleteAction: EntryDeleteAction?
    @Environment(ErrorState.self) private var errorState: ErrorState?

    private var oneOnOneDir: URL {
        personURL.appendingPathComponent("1-1", isDirectory: true)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No 1-1s",
                    systemImage: "person.2",
                    description: Text("Start a recording to create a 1-1.")
                )
            } else {
                dateNavigationDetail
            }
        }
        .onAppear { loadEntries(); loadConfig() }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
            loadEntries()
        }
        .sheet(isPresented: $showConfigSheet) {
            if let runner = skillRunner {
                MeetingConfigSheet(
                    folderName: "1-1",
                    folderURL: oneOnOneDir,
                    config: $meetingConfig,
                    runner: runner
                )
                .frame(width: 400, height: 500)
            }
        }
    }

    // MARK: - Data loading

    private func loadEntries() {
        let dir = oneOnOneDir
        Task {
            let result = await Task.detached {
                MeetingDateEntry.scan(in: dir)
            }.value
            entries = result
        }
    }

    private func loadConfig() {
        let dir = oneOnOneDir
        Task {
            meetingConfig = await Task.detached { MeetingConfig.load(from: dir) }.value
        }
    }

    // MARK: - Date navigation

    private var dateNavigationDetail: some View {
        let safeIndex = min(index, entries.count - 1)
        let entry = entries[max(safeIndex, 0)]

        return VStack(spacing: 0) {
            DateNavigationHeader(
                entry: entry,
                totalEntries: entries.count,
                index: $index,
                showTranscripts: $showTranscripts,
                config: meetingConfig,
                skillRunner: skillRunner,
                showConfigAction: skillRunner != nil ? { showConfigSheet = true } : nil,
                entryDeleteAction: $entryDeleteAction,
                nextFileURL: oneOnOneDir.appendingPathComponent("next.md")
            )
            Divider()
            DateEntryContentView(
                entry: entry, markdownTheme: markdownTheme, showTranscripts: $showTranscripts
            )
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
                errorState?.show(String(localized: "Unable to delete: \(error.localizedDescription)"))
            }
            loadEntries()
        }
    }
}

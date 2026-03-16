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
            .onReceive(NotificationCenter.default.publisher(for: .skillRunnerDidFinish)) { _ in
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
                addLabel: "Nouvelle évaluation", emptyTitle: "Aucune évaluation",
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
                addLabel: "Nouvel objectif", emptyTitle: "Aucun objectif",
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
                    .help("Importer un fichier ou un lien")
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
            errorState?.show("Impossible de supprimer « \(file.name) » : \(error.localizedDescription)")
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
                    "Aucun 1-1",
                    systemImage: "person.2",
                    description: Text("Lancez un enregistrement pour créer un 1-1.")
                )
            } else {
                dateNavigationDetail
            }
        }
        .onAppear { loadEntries(); loadConfig() }
        .onChange(of: skillRunner?.isRunning) {
            if skillRunner?.isRunning == false { loadEntries() }
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
                let mdFiles = DirectoryScanner.scan(at: dir, fileExtension: "md").files
                let transcriptFiles = DirectoryScanner.scan(at: dir, fileExtension: "transcript").files
                let storage = FileTranscriptionStorage()
                let dateParser = DateFormatter()
                dateParser.dateFormat = "yyyy-MM-dd"
                dateParser.locale = Locale(identifier: "en_US_POSIX")

                var dateMap: [String: (note: FolderFile?, transcript: StoredTranscript?)] = [:]

                for file in mdFiles {
                    let datePrefix = file.url.deletingPathExtension().lastPathComponent
                    let folderFile = FolderFile(id: file.url, name: datePrefix, date: file.date, url: file.url)
                    dateMap[datePrefix, default: (nil, nil)].note = folderFile
                }
                for file in transcriptFiles {
                    let datePrefix = file.url.deletingPathExtension().lastPathComponent
                    if let parsed = storage.parseTranscriptFile(at: file.url) {
                        dateMap[datePrefix, default: (nil, nil)].transcript = parsed
                    }
                }
                return dateMap.map { key, value in
                    let date = dateParser.date(from: key)
                        ?? value.note?.date ?? value.transcript?.date ?? Date.distantPast
                    return MeetingDateEntry(dateString: key, date: date, noteFile: value.note, transcript: value.transcript)
                }
                .sorted { (a: MeetingDateEntry, b: MeetingDateEntry) in
                    a.dateString.localizedStandardCompare(b.dateString) == .orderedDescending
                }
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
            dateHeader(entry: entry, totalEntries: entries.count)
            Divider()

            if showTranscripts, let transcript = entry.transcript {
                TranscriptDetailView(transcript: transcript).id(transcript.id)
            } else if let file = entry.noteFile {
                FolderFileEditorView(file: file, markdownTheme: markdownTheme).id(file.id)
            } else if let transcript = entry.transcript {
                TranscriptDetailView(transcript: transcript).id(transcript.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: index) { showTranscripts = false }
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
                    performDelete(action)
                    entryDeleteAction = nil
                }
            }
        } message: {
            if let action = entryDeleteAction { Text(action.message) }
        }
    }

    private func dateHeader(entry: MeetingDateEntry, totalEntries: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                Button {
                    if index < totalEntries - 1 { index += 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .interactiveHover()
                .disabled(index >= totalEntries - 1)

                Spacer()
                Text(entry.date, format: .dateTime.day().month(.wide).year()).font(.headline)
                Spacer()

                Button {
                    if index > 0 { index -= 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .interactiveHover()
                .disabled(index <= 0)
            }

            HStack(spacing: 8) {
                Spacer()
                transcriptToggleButton(for: entry)
                if skillRunner != nil {
                    runActionsMenu
                    configToggleButton
                }
                entryActionsMenu(for: entry)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func transcriptToggleButton(for entry: MeetingDateEntry) -> some View {
        let canToggle = entry.hasNote && entry.hasTranscript
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { showTranscripts.toggle() }
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
    }

    @ViewBuilder
    private var runActionsMenu: some View {
        let actions = meetingConfig.actions
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
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill").font(.body)
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
        }
    }

    private var configToggleButton: some View {
        Button {
            showConfigSheet = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .interactiveHover()
    }

    private func entryActionsMenu(for entry: MeetingDateEntry) -> some View {
        Menu {
            if entry.hasNote {
                Button(role: .destructive) { entryDeleteAction = .note(entry) } label: {
                    Label("Supprimer la note", systemImage: "doc.text")
                }
            }
            if entry.hasTranscript {
                Button(role: .destructive) { entryDeleteAction = .transcript(entry) } label: {
                    Label("Supprimer le transcript", systemImage: "waveform")
                }
            }
            if entry.hasNote && entry.hasTranscript {
                Divider()
                Button(role: .destructive) { entryDeleteAction = .both(entry) } label: {
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

    private func performDelete(_ action: EntryDeleteAction) {
        let entry = action.entry
        do {
            switch action {
            case .note:
                if let note = entry.noteFile { try FileManager.default.removeItem(at: note.url) }
            case .transcript:
                if let transcript = entry.transcript { try FileManager.default.removeItem(at: transcript.url) }
            case .both:
                if let note = entry.noteFile { try FileManager.default.removeItem(at: note.url) }
                if let transcript = entry.transcript { try FileManager.default.removeItem(at: transcript.url) }
            }
        } catch {
            errorState?.show("Impossible de supprimer : \(error.localizedDescription)")
        }
        loadEntries()
    }
}

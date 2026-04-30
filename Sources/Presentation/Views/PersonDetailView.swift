import SwiftUI

struct PersonDetailView: View {
    let personName: String
    let personURL: URL
    @Binding var activeSection: PersonSection
    let personBreadcrumbSegment: BreadcrumbSegment
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var recordingViewModel: RecordingViewModel?
    var consoleViewModel: ConsoleViewModel?
    var oneOnOneActiveFileURL: Binding<URL?>?

    @State private var assessmentFiles: [FolderFile] = []
    @State private var objectifsFiles: [FolderFile] = []
    @State private var assessmentIndex: Int = 0
    @State private var objectifIndex: Int = 0
    @State private var isAddingAssessment = false
    @State private var isAddingObjectif = false
    @State private var newFileName = ""
    @Environment(ErrorState.self) private var errorState: ErrorState?

    private var leadingSegments: [BreadcrumbSegment] {
        [personBreadcrumbSegment, sectionBreadcrumbSegment]
    }

    private var sectionBreadcrumbSegment: BreadcrumbSegment {
        let isFolder: Bool = {
            switch activeSection {
            case .oneOnOne, .assessment, .objectifs: true
            case .profile, .jobDescription: false
            }
        }()
        let label: String
        switch activeSection {
        case .oneOnOne: label = "1-1"
        case .assessment: label = "assessment"
        case .objectifs: label = "objectifs"
        case .profile: label = "profile.md"
        case .jobDescription: label = "job-description.md"
        }
        let siblings = PersonSection.allCases.map { section in
            BreadcrumbSibling(
                id: section.rawValue,
                label: PersonDetailView.breadcrumbLabel(for: section),
                sub: section.localizedName,
                leading: .symbol(section.icon),
                active: section == activeSection
            )
        }
        return BreadcrumbSegment(
            id: "section",
            label: label,
            kind: isFolder ? .folder : .file,
            popoverTitle: String(localized: "Sections"),
            groups: [BreadcrumbSiblingGroup(id: "all", title: nil, siblings: siblings)],
            onPick: { rawValue in
                if let section = PersonSection(rawValue: rawValue) {
                    activeSection = section
                }
            }
        )
    }

    fileprivate static func breadcrumbLabel(for section: PersonSection) -> String {
        switch section {
        case .oneOnOne: return "1-1"
        case .assessment: return "assessment"
        case .objectifs: return "objectifs"
        case .profile: return "profile.md"
        case .jobDescription: return "job-description.md"
        }
    }

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
            simpleFileSection(fileName: "profile.md", trailingActions: { EmptyView() })
        case .jobDescription:
            simpleFileSection(fileName: "job-description.md") {
                jobDescriptionImportButton(fileURL: personURL.appendingPathComponent("job-description.md"))
            }
        case .oneOnOne:
            PersonOneOnOneView(
                personURL: personURL,
                leadingSegments: leadingSegments,
                markdownTheme: markdownTheme,
                consoleViewModel: consoleViewModel,
                activeFileURL: oneOnOneActiveFileURL
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
                leadingSegments: leadingSegments,
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
                leadingSegments: leadingSegments,
                onCreate: { createSubfolderFile(subfolder: "objectifs", isAdding: $isAddingObjectif) },
                onDelete: { deleteSubfolderFile($0, subfolder: "objectifs") }
            )
        }
    }

    // MARK: - Simple file section (profile, job description)

    @ViewBuilder
    private func simpleFileSection<Trailing: View>(
        fileName: String,
        @ViewBuilder trailingActions: () -> Trailing
    ) -> some View {
        let fileURL = personURL.appendingPathComponent(fileName)
        let file = FolderFile(
            id: fileURL,
            name: fileURL.deletingPathExtension().lastPathComponent,
            date: (try? FileManager.default.attributesOfItem(
                atPath: fileURL.path
            )[.modificationDate] as? Date) ?? Date(),
            url: fileURL
        )
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                BreadcrumbBar(segments: leadingSegments)
                Spacer(minLength: 8)
                trailingActions()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider().opacity(0.5)
            FolderFileEditorView(file: file, markdownTheme: markdownTheme)
                .id(fileName)
        }
    }

    private func jobDescriptionImportButton(fileURL: URL) -> some View {
        Group {
            if let console = consoleViewModel {
                Button {
                    ImportDocumentHelper.pickFile(
                        targetPath: fileURL.path,
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
        }
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
    var leadingSegments: [BreadcrumbSegment]
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var consoleViewModel: ConsoleViewModel?
    var activeFileURL: Binding<URL?>?

    @State private var entries: [MeetingDateEntry] = []
    @State private var index: Int = 0
    @State private var showTranscripts = false
    @State private var entryDeleteAction: EntryDeleteAction?
    @Environment(ErrorState.self) private var errorState: ErrorState?

    private var oneOnOneDir: URL {
        personURL.appendingPathComponent("1-1", isDirectory: true)
    }

    var body: some View {
        contentBody
        .onAppear {
            loadEntries()
            publishActiveFile()
        }
        .onChange(of: index) { publishActiveFile() }
        .onChange(of: showTranscripts) { publishActiveFile() }
        .onChange(of: entries.map(\.dateString)) { publishActiveFile() }
        .onDisappear { activeFileURL?.wrappedValue = nil }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { notif in
            guard notif.affectsPath(oneOnOneDir) else { return }
            loadEntries()
        }
    }

    private func publishActiveFile() {
        guard let binding = activeFileURL else { return }
        let url: URL? = {
            guard let entry = currentEntry else { return nil }
            if showTranscripts, let t = entry.transcriptFile { return t.url }
            return entry.noteFile?.url ?? entry.transcriptFile?.url
        }()
        if binding.wrappedValue != url {
            binding.wrappedValue = url
        }
    }

    // MARK: - Data loading

    private func loadEntries() {
        let dir = oneOnOneDir
        Task {
            entries = await MeetingDateEntry.scan(in: dir)
        }
    }

    // MARK: - Layout

    private var currentEntry: MeetingDateEntry? {
        guard !entries.isEmpty else { return nil }
        let safeIndex = min(index, entries.count - 1)
        return entries[max(safeIndex, 0)]
    }

    private var contentBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                BreadcrumbBar(segments: leadingSegments + [dateFileSegment])
                Spacer(minLength: 8)
                if let entry = currentEntry {
                    TranscriptPill(entry: entry, showTranscripts: $showTranscripts)
                    EntryMoreMenu(entry: entry, entryDeleteAction: $entryDeleteAction)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider().opacity(0.5)
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
            handleEntryDelete(action: action, errorState: errorState)
        }
    }

    private var dateFileSegment: BreadcrumbSegment {
        let label: String
        if let entry = currentEntry {
            let ext = showTranscripts && entry.hasTranscript ? "transcript" : "md"
            label = "\(entry.dateString).\(ext)"
        } else {
            label = "—"
        }
        return BreadcrumbSegment(
            id: "1-1-file",
            label: label,
            kind: .file,
            popoverTitle: String(localized: "Occurrences"),
            emptyMessage: String(localized: "No 1-1s yet"),
            groups: [BreadcrumbSiblingGroup(
                id: "all",
                title: nil,
                siblings: entries.map { entry in
                    BreadcrumbSibling(
                        id: entry.dateString,
                        label: "\(entry.dateString).md",
                        sub: dateSubtitle(for: entry.date),
                        leading: .symbol("doc.text"),
                        active: entry.dateString == currentEntry?.dateString
                    )
                }
            )],
            onPick: { dateString in
                if let idx = entries.firstIndex(where: { $0.dateString == dateString }) {
                    index = idx
                }
            }
        )
    }

    private func dateSubtitle(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func handleEntryDelete(action: EntryDeleteAction, errorState: ErrorState?) {
        let entry = action.entry
        do {
            switch action {
            case .note:
                if let note = entry.noteFile { try FileManager.default.removeItem(at: note.url) }
            case .transcript:
                if let t = entry.transcriptFile { try FileManager.default.removeItem(at: t.url) }
            case .both:
                if let note = entry.noteFile { try FileManager.default.removeItem(at: note.url) }
                if let t = entry.transcriptFile { try FileManager.default.removeItem(at: t.url) }
            }
        } catch {
            IssueLogger.log(.error, "Failed to delete person entry", error: error)
            errorState?.show(String(localized: "Unable to delete: \(error.localizedDescription)"))
        }
        loadEntries()
    }
}

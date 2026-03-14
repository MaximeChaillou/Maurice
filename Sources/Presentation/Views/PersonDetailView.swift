import SwiftUI

struct PersonDetailView: View {
    let personName: String
    let personURL: URL
    let activeSection: PersonSection
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    var recordingViewModel: RecordingViewModel?
    var skillRunner: SkillRunner?

    @State private var evaluationsFiles: [FolderFile] = []
    @State private var objectifsFiles: [FolderFile] = []
    @State private var evaluationIndex: Int = 0
    @State private var objectifIndex: Int = 0
    @State private var isAddingEvaluation = false
    @State private var isAddingObjectif = false
    @State private var newFileName = ""
    @State private var showImportFiche = false
    @State private var showImportEvaluation = false
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
        case .profil:
            markdownFileEditor(fileName: "profil.md")
        case .ficheDePoste:
            ficheDePosteSection
        case .oneOnOne:
            PersonOneOnOneView(personURL: personURL, markdownTheme: markdownTheme)
        case .evaluations:
            SubfolderNavigationView(
                files: evaluationsFiles, index: $evaluationIndex,
                isAdding: $isAddingEvaluation, newFileName: $newFileName,
                addLabel: "Nouvelle évaluation", emptyTitle: "Aucune évaluation",
                emptyIcon: "checkmark.seal", markdownTheme: markdownTheme,
                skillRunner: skillRunner,
                subfolderURL: personURL.appendingPathComponent("evaluations", isDirectory: true),
                onCreate: { createSubfolderFile(subfolder: "evaluations", isAdding: $isAddingEvaluation) },
                onDelete: { deleteSubfolderFile($0, subfolder: "evaluations") }
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

    // MARK: - Fiche de poste with import

    @ViewBuilder
    private var ficheDePosteSection: some View {
        let fileURL = personURL.appendingPathComponent("fiche-de-poste.md")
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
                        showImportFiche = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .help("Importer un fichier ou un lien")
                    .popover(isPresented: $showImportFiche) {
                        ImportDocumentView(
                            targetPath: fileURL.path,
                            runner: runner,
                            onDismiss: { showImportFiche = false }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()
            }

            FolderFileEditorView(file: file, markdownTheme: markdownTheme)
        }
        .id("fiche-de-poste.md")
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
            let evals = await Self.scanSubfolder("evaluations", in: url)
            let objs = await Self.scanSubfolder("objectifs", in: url)
            evaluationsFiles = evals
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
        if subfolder == "evaluations" {
            evaluationIndex = 0
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
        if subfolder == "evaluations" {
            evaluationIndex = min(evaluationIndex, max(evaluationsFiles.count - 1, 0))
        } else {
            objectifIndex = min(objectifIndex, max(objectifsFiles.count - 1, 0))
        }
    }
}

// MARK: - 1-1 View

struct PersonOneOnOneView: View {
    let personURL: URL
    var markdownTheme: MarkdownTheme = MarkdownTheme()

    @State private var entries: [MeetingDateEntry] = []
    @State private var showTranscripts = false
    @State private var index: Int = 0
    @State private var entryDeleteAction: EntryDeleteAction?
    @Environment(ErrorState.self) private var errorState: ErrorState?

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "Aucun 1-1",
                systemImage: "person.2",
                description: Text("Lancez un enregistrement pour créer un 1-1.")
            )
            .onAppear { loadEntries() }
        } else {
            dateNavigation(entries: entries)
                .onAppear { loadEntries() }
        }
    }

    private func loadEntries() {
        let dir = personURL.appendingPathComponent("1-1", isDirectory: true)
        Task {
            let result = await Task.detached {
                let mdFiles = DirectoryScanner.scan(at: dir, fileExtension: "md").files
                let transcriptFiles = DirectoryScanner.scan(at: dir, fileExtension: "transcript").files
                let storage = FileTranscriptionStorage()
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
                    let date = value.note?.date ?? value.transcript?.date ?? Date.distantPast
                    return MeetingDateEntry(dateString: key, date: date, noteFile: value.note, transcript: value.transcript)
                }
                .sorted { (a: MeetingDateEntry, b: MeetingDateEntry) in
                    a.dateString.localizedStandardCompare(b.dateString) == .orderedDescending
                }
            }.value
            entries = result
        }
    }

    private func dateNavigation(entries: [MeetingDateEntry]) -> some View {
        let safeIndex = min(index, entries.count - 1)
        let entry = entries[max(safeIndex, 0)]

        return VStack(spacing: 0) {
            dateHeader(entry: entry, totalEntries: entries.count)
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

            Divider()
            entryContent(for: entry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: index) { showTranscripts = false }
    }

    private func dateHeader(entry: MeetingDateEntry, totalEntries: Int) -> some View {
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
            .disabled(index <= 0)

            transcriptToggle(for: entry)
            entryMenu(for: entry)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func entryContent(for entry: MeetingDateEntry) -> some View {
        if showTranscripts, let transcript = entry.transcript {
            TranscriptDetailView(transcript: transcript).id(transcript.id)
        } else if let file = entry.noteFile {
            FolderFileEditorView(file: file, markdownTheme: markdownTheme).id(file.id)
        } else if let transcript = entry.transcript {
            TranscriptDetailView(transcript: transcript).id(transcript.id)
        }
    }

    private func transcriptToggle(for entry: MeetingDateEntry) -> some View {
        let canToggle = entry.hasNote && entry.hasTranscript
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { showTranscripts.toggle() }
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
    }

    private func entryMenu(for entry: MeetingDateEntry) -> some View {
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
        .glassEffect(.regular.interactive(), in: .circle)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 32, height: 32)
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
    }
}

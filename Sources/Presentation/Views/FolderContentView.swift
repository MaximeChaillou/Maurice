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

    var body: some View {
        HStack(spacing: 0) {
            folderList
                .frame(width: 240)

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .inspector(isPresented: $showConfigSidebar) {
            if let folderName = viewModel.selectedFolder, let runner = skillRunner {
                MeetingConfigSidebar(
                    folderName: folderName,
                    config: $viewModel.skillConfig,
                    runner: runner
                )
                .presentationBackground(.clear)
            }
        }
        .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
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
                        Text(folder.name)
                            .font(.body)
                            .lineLimit(1)
                        Text("\(folder.fileCount) fichier\(folder.fileCount > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(folder.name)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: viewModel.selectedFolder) {
                viewModel.selectedFile = nil
                recordingViewModel?.subdirectory = viewModel.selectedFolder
                if navigateByDate, let folder = viewModel.currentFolder {
                    viewModel.fileIndex = 0
                    viewModel.selectFileAtIndex(in: folder)
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
            if navigateByDate {
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

    // MARK: - Navigate by date mode

    @State private var showTranscripts = false

    private func dateNavigationDetail(for folder: FolderItem) -> some View {
        let sortedFiles = folder.files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        let safeIndex = min(viewModel.fileIndex, sortedFiles.count - 1)
        let file = sortedFiles[max(safeIndex, 0)]

        return VStack(spacing: 0) {
            dateNavigationHeader(file: file, totalFiles: sortedFiles.count)
            Divider()

            if showTranscripts {
                MeetingTranscriptsView(meetingName: folder.name)
            } else {
                FolderFileEditorView(file: file, markdownTheme: markdownTheme)
                    .id(file.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dateNavigationHeader(file: FolderFile, totalFiles: Int) -> some View {
        HStack {
            Button {
                if viewModel.fileIndex < totalFiles - 1 { viewModel.fileIndex += 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.fileIndex >= totalFiles - 1)

            Spacer()

            VStack(spacing: 2) {
                Text(file.name)
                    .font(.headline)
                Text(file.date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if viewModel.fileIndex > 0 { viewModel.fileIndex -= 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.fileIndex <= 0)

            if navigateByDate {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTranscripts.toggle()
                    }
                } label: {
                    Image(systemName: showTranscripts ? "doc.text" : "waveform")
                        .font(.body)
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .help(showTranscripts ? "Afficher les notes" : "Afficher les transcripts")
            }

            if showSkillConfig, skillRunner != nil {
                configToggleButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - File list mode

    private func fileListDetail(for folder: FolderItem) -> some View {
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

    private func fileList(for folder: FolderItem) -> some View {
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

    // MARK: - Config sidebar toggle

    private var configToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showConfigSidebar.toggle()
            }
        } label: {
            Image(systemName: showConfigSidebar ? "sidebar.trailing" : "gearshape")
                .font(.body)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .help("Configurer les skills")
    }
}

// MARK: - Models

struct FolderItem: Identifiable {
    let name: String, url: URL, files: [FolderFile]
    var id: String { name }
    var fileCount: Int { files.count }
}

struct FolderFile: Identifiable, Hashable {
    let id: URL, name: String, date: Date, url: URL
    var content: String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    func save(content: String) { try? content.write(to: url, atomically: true, encoding: .utf8) }
}

// MARK: - Detail views

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

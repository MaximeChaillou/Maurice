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
    @State private var showTranscriptOverlay: Bool = false

    private var isSidebarVisible: Bool {
        showSkillConfig && showConfigSidebar && viewModel.selectedFolder != nil
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HSplitView {
                        folderList
                            .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
                            .layoutPriority(1)

                        detailPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: isSidebarVisible ? geo.size.width - 321 : geo.size.width)

                if isSidebarVisible, let runner = skillRunner {
                    Divider()
                    MeetingConfigSidebar(
                        folderName: viewModel.selectedFolder!,
                        config: $viewModel.skillConfig,
                        runner: runner
                    )
                    .transition(.move(edge: .trailing))
                }
            }
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
                }
            }
            .onChange(of: viewModel.selectedFolder) {
                viewModel.selectedFile = nil
                showTranscriptOverlay = false
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

    private func dateNavigationDetail(for folder: FolderItem) -> some View {
        let sortedFiles = folder.files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        let safeIndex = min(viewModel.fileIndex, sortedFiles.count - 1)
        let file = sortedFiles[max(safeIndex, 0)]

        return VStack(spacing: 0) {
            dateNavigationHeader(file: file, totalFiles: sortedFiles.count)
            Divider()

            FolderFileEditorView(file: file, markdownTheme: markdownTheme)
                .id(file.id)

            if let vm = recordingViewModel {
                TabButtonRepresentable(isOpen: showTranscriptOverlay) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showTranscriptOverlay.toggle()
                    }
                }
                .frame(width: 60, height: 22)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 40)
                .padding(.top, -22)
                .zIndex(1)

                if showTranscriptOverlay {
                    MeetingTranscriptContent(viewModel: vm)
                }

                Divider()
                RecordingControlBar(viewModel: vm)
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

            if showSkillConfig {
                configToggleButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - File list mode

    private func fileListDetail(for folder: FolderItem) -> some View {
        HSplitView {
            fileList(for: folder)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

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
            }
        }
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

// MARK: - Meeting transcript tab & content

private struct TabButtonRepresentable: NSViewRepresentable {
    let isOpen: Bool
    let action: () -> Void

    func makeNSView(context: Context) -> TabButtonNSView {
        let view = TabButtonNSView()
        view.action = action
        view.isOpen = isOpen
        return view
    }

    func updateNSView(_ nsView: TabButtonNSView, context: Context) {
        nsView.isOpen = isOpen
        nsView.action = action
        nsView.needsDisplay = true
    }
}

private final class TabButtonNSView: NSView {
    var isOpen = false
    var action: (() -> Void)?
    private var cursorTrackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = cursorTrackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeAlways],
            owner: self
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius: CGFloat = 6
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: bounds.minX + radius, y: bounds.maxY),
                          control: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.maxX - radius, y: bounds.maxY))
        path.addQuadCurve(to: CGPoint(x: bounds.maxX, y: bounds.maxY - radius),
                          control: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.closeSubpath()

        let nsPath = NSBezierPath(cgPath: path)
        NSColor.controlBackgroundColor.withAlphaComponent(0.6).setFill()
        nsPath.fill()

        // Chevron
        let name = isOpen ? "chevron.down" : "chevron.up"
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            .applying(.init(paletteColors: [.secondaryLabelColor]))
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let size = image.size
            let point = NSPoint(x: (bounds.width - size.width) / 2,
                                y: (bounds.height - size.height) / 2)
            image.draw(at: point, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    override func mouseDown(with event: NSEvent) {
        action?()
    }
}

private struct MeetingTranscriptContent: View {
    let viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView {
                if viewModel.entries.isEmpty && viewModel.volatileText.isEmpty {
                    Text("En attente de transcription…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    BubbleListView(
                        entries: viewModel.entries.map(\.text),
                        volatileText: viewModel.volatileText,
                        autoScroll: true
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .background(.background)
    }
}

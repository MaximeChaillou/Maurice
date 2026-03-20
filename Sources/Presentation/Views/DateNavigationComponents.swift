import SwiftUI

// MARK: - Date Navigation Header

struct DateNavigationHeader: View {
    let entry: MeetingDateEntry
    let totalEntries: Int
    @Binding var index: Int
    @Binding var showTranscripts: Bool
    var config: MeetingConfig?
    var skillRunner: SkillRunner?
    var showConfigAction: (() -> Void)?
    @Binding var entryDeleteAction: EntryDeleteAction?
    var nextFileURL: URL?

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                navButton(direction: .backward)
                Spacer()
                Text(entry.date, format: .dateTime.day().month(.wide).year())
                    .font(.headline)
                Spacer()
                navButton(direction: .forward)
            }

            HStack(spacing: 8) {
                Spacer()
                if let nextFileURL {
                    NextNoteButton(fileURL: nextFileURL)
                }
                TranscriptToggleButton(entry: entry, showTranscripts: $showTranscripts)
                if let config, let skillRunner {
                    SkillActionsMenu(config: config, runner: skillRunner, activeFilePath: entry.noteFile?.url.path ?? entry.transcript?.url.path)
                    if let showConfigAction {
                        GlassIconButton(icon: "gearshape", help: "Configure skills") {
                            showConfigAction()
                        }
                    }
                }
                EntryActionsMenu(entry: entry, entryDeleteAction: $entryDeleteAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private enum Direction { case forward, backward }

    private func navButton(direction: Direction) -> some View {
        let isBackward = direction == .backward
        return Button {
            if isBackward {
                if index < totalEntries - 1 { index += 1 }
            } else {
                if index > 0 { index -= 1 }
            }
        } label: {
            Image(systemName: isBackward ? "chevron.left" : "chevron.right")
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .interactiveHover()
        .help(isBackward ? String(localized: "Previous entry") : String(localized: "Next entry"))
        .disabled(isBackward ? index >= totalEntries - 1 : index <= 0)
    }
}

// MARK: - Date Entry Content

struct DateEntryContentView: View {
    let entry: MeetingDateEntry
    var markdownTheme: MarkdownTheme = MarkdownTheme()
    @Binding var showTranscripts: Bool

    var body: some View {
        if showTranscripts, let transcript = entry.transcript {
            TranscriptDetailView(transcript: transcript).id(transcript.id)
        } else if let file = entry.noteFile {
            FolderFileEditorView(file: file, markdownTheme: markdownTheme).id(file.id)
        } else if let transcript = entry.transcript {
            TranscriptDetailView(transcript: transcript).id(transcript.id)
        }
    }
}

// MARK: - Transcript Toggle Button

struct TranscriptToggleButton: View {
    let entry: MeetingDateEntry
    @Binding var showTranscripts: Bool

    var body: some View {
        let canToggle = entry.hasNote && entry.hasTranscript
        Button {
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
        .help(
            !canToggle
                ? (entry.hasNote ? String(localized: "No transcript") : String(localized: "No note"))
                : (showTranscripts ? String(localized: "Show notes") : String(localized: "Show transcripts"))
        )
    }
}

// MARK: - Skill Actions Menu

struct SkillActionsMenu: View {
    let config: MeetingConfig
    let runner: SkillRunner
    var activeFilePath: String?

    var body: some View {
        let actions = config.actions
        if !actions.isEmpty {
            Menu {
                ForEach(actions) { action in
                    Button {
                        guard !runner.isRunning else { return }
                        runner.actionID = action.id
                        let filePrefix = activeFilePath.map { $0 + " " } ?? ""
                        let fullParameter = filePrefix + (action.parameter ?? "")
                        runner.run(
                            skillFilename: action.skillFilename,
                            buttonName: action.buttonName,
                            parameter: fullParameter.isEmpty ? nil : fullParameter,
                            workingDirectory: AppSettings.rootDirectory
                        )
                    } label: {
                        Label(action.buttonName, systemImage: "play.fill")
                    }
                    .disabled(runner.isRunning)
                }
            } label: {
                ZStack {
                    if runner.isRunning {
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
            .help("Run an action")
        }
    }
}

// MARK: - Entry Actions Menu

struct EntryActionsMenu: View {
    let entry: MeetingDateEntry
    @Binding var entryDeleteAction: EntryDeleteAction?

    var body: some View {
        Menu {
            if entry.hasNote {
                Button(role: .destructive) { entryDeleteAction = .note(entry) } label: {
                    Label("Delete note", systemImage: "doc.text")
                }
            }
            if entry.hasTranscript {
                Button(role: .destructive) { entryDeleteAction = .transcript(entry) } label: {
                    Label("Delete transcript", systemImage: "waveform")
                }
            }
            if entry.hasNote && entry.hasTranscript {
                Divider()
                Button(role: .destructive) { entryDeleteAction = .both(entry) } label: {
                    Label("Delete all", systemImage: "trash")
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
        .help("Delete...")
    }
}

// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    var help: LocalizedStringKey = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .interactiveHover()
        .help(help)
    }
}

// MARK: - Next Note Button

struct NextNoteButton: View {
    let fileURL: URL
    @State private var showPopover = false
    @State private var hasContent = false

    var body: some View {
        Button {
            ensureFileExists()
            showPopover.toggle()
        } label: {
            Image(systemName: "text.badge.plus")
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if hasContent {
                        Circle()
                            .fill(.orange)
                            .frame(width: 7, height: 7)
                            .offset(x: 2, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .interactiveHover()
        .help("Notes for next meeting")
        .popover(isPresented: $showPopover) {
            VStack(spacing: 0) {
                Text("Notes for next meeting — next.md")
                    .font(.headline)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                Divider()
                FolderFileEditorView(
                    file: FolderFile(url: fileURL),
                    markdownTheme: MarkdownTheme()
                )
            }
            .frame(width: 400, height: 300)
        }
        .onAppear { checkContent() }
        .onChange(of: showPopover) { if !showPopover { checkContent() } }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { _ in
            checkContent()
        }
    }

    private func checkContent() {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            hasContent = false
            return
        }
        hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func ensureFileExists() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }
}

// MARK: - Generic Deletion Alert Modifier

struct DeletionAlertModifier<Item: Identifiable>: ViewModifier {
    let title: LocalizedStringKey
    @Binding var item: Item?
    let message: (Item) -> String
    let onDelete: (Item) -> Void

    func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: Binding(
                get: { item != nil },
                set: { if !$0 { item = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { item = nil }
            Button("Delete", role: .destructive) {
                if let toDelete = item {
                    onDelete(toDelete)
                    item = nil
                }
            }
        } message: {
            if let toDelete = item { Text(message(toDelete)) }
        }
    }
}

extension View {
    func deletionAlert<Item: Identifiable>(
        _ title: LocalizedStringKey,
        item: Binding<Item?>,
        message: @escaping (Item) -> String,
        onDelete: @escaping (Item) -> Void
    ) -> some View {
        modifier(DeletionAlertModifier(title: title, item: item, message: message, onDelete: onDelete))
    }
}

// MARK: - Entry Delete Alert Modifier

struct EntryDeleteAlertModifier: ViewModifier {
    @Binding var entryDeleteAction: EntryDeleteAction?
    let onDelete: (EntryDeleteAction) -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Delete?",
            isPresented: Binding(
                get: { entryDeleteAction != nil },
                set: { if !$0 { entryDeleteAction = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { entryDeleteAction = nil }
            Button("Delete", role: .destructive) {
                if let action = entryDeleteAction {
                    onDelete(action)
                    entryDeleteAction = nil
                }
            }
        } message: {
            if let action = entryDeleteAction { Text(action.message) }
        }
    }
}

extension View {
    func entryDeleteAlert(
        action: Binding<EntryDeleteAction?>,
        onDelete: @escaping (EntryDeleteAction) -> Void
    ) -> some View {
        modifier(EntryDeleteAlertModifier(entryDeleteAction: action, onDelete: onDelete))
    }
}

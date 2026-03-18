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
                TranscriptToggleButton(entry: entry, showTranscripts: $showTranscripts)
                if let config, let skillRunner {
                    SkillActionsMenu(config: config, runner: skillRunner, activeFilePath: entry.noteFile?.url.path ?? entry.transcript?.url.path)
                    if let showConfigAction {
                        GlassIconButton(icon: "gearshape", help: "Configurer les skills") {
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
                ? (entry.hasNote ? "Pas de transcript" : "Pas de note")
                : (showTranscripts ? "Afficher les notes" : "Afficher les transcripts")
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
            .help("Lancer une action")
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
}

// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    var help: String = ""
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

// MARK: - Generic Deletion Alert Modifier

struct DeletionAlertModifier<Item: Identifiable>: ViewModifier {
    let title: String
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
            Button("Annuler", role: .cancel) { item = nil }
            Button("Supprimer", role: .destructive) {
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
        _ title: String,
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
            "Supprimer ?",
            isPresented: Binding(
                get: { entryDeleteAction != nil },
                set: { if !$0 { entryDeleteAction = nil } }
            )
        ) {
            Button("Annuler", role: .cancel) { entryDeleteAction = nil }
            Button("Supprimer", role: .destructive) {
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

import SwiftUI

// MARK: - Tab Pill Button

/// Generic pill-styled action button used in the doc header and content card toolbar.
/// `[icon] Label [trailingDetail] [dot] [chevron]`
struct TabPillButton: View {
    let label: LocalizedStringKey
    let systemImage: String
    var trailingDetail: String?
    var active: Bool = false
    var dot: Bool = false
    var hasChevron: Bool = false
    var disabled: Bool = false
    var help: LocalizedStringKey = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            TabPillLabel(
                label: label,
                systemImage: systemImage,
                trailingDetail: trailingDetail,
                active: active,
                dot: dot,
                hasChevron: hasChevron
            )
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }
}

/// Visual content of a pill (icon, label, optional trailing details, dot, chevron)
/// rendered with the shared pill background. Used as the body of both
/// `TabPillButton` and `Menu`-backed pills so they share the exact same shape.
struct TabPillLabel: View {
    let label: LocalizedStringKey
    let systemImage: String
    var trailingDetail: String?
    var active: Bool = false
    var dot: Bool = false
    var hasChevron: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .medium))
            Text(label)
                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
            if let trailingDetail {
                Text(trailingDetail)
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .opacity(active ? 0.85 : 1)
            }
            if dot {
                Circle()
                    .fill(active ? Color.cyan : Color.cyan.opacity(0.85))
                    .frame(width: 5, height: 5)
            }
            if hasChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .opacity(0.7)
            }
        }
        .foregroundStyle(active ? Color.cyan : Color.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(height: 24)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(active ? Color.cyan.opacity(0.14) : Color.primary.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            active ? Color.cyan.opacity(0.35) : Color.primary.opacity(0.08),
                            lineWidth: 0.5
                        )
                }
        }
        .contentShape(.rect(cornerRadius: 6))
    }
}

// MARK: - Tab Square Button

/// Small rounded square button used for ellipsis / icon-only actions in the toolbar.
struct TabSquareButton: View {
    let systemImage: String
    var help: LocalizedStringKey = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Quick Notes (next.md) Pill

/// "Notes" pill with a popover editor for the next-meeting notes file.
/// Shows an accent dot when the file has content.
struct QuickNotesPillButton: View {
    let fileURL: URL
    @State private var showPopover = false
    @State private var hasContent = false

    var body: some View {
        TabPillButton(
            label: "Notes",
            systemImage: "pencil",
            active: showPopover,
            dot: hasContent,
            hasChevron: true,
            help: "Notes for next meeting",
            action: {
                ensureFileExists()
                showPopover.toggle()
            }
        )
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
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
        .onChange(of: fileURL) { _, _ in checkContent() }
        .onChange(of: showPopover) { if !showPopover { checkContent() } }
        .onReceive(NotificationCenter.default.publisher(for: .fileSystemDidChange)) { notif in
            guard notif.affectsPath(fileURL) else { return }
            checkContent()
        }
    }

    private func checkContent() {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            if !error.isFileNotFound {
                IssueLogger.log(.warning, "Failed to read next.md content",
                                context: fileURL.path, error: error)
            }
            hasContent = false
        }
    }

    private func ensureFileExists() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }
}

// MARK: - Skills Pill Menu

/// "Skills" pill that opens a popover listing configured skill actions plus
/// a single footer entry that opens the meeting config sheet. Implemented as
/// a `Button` + `popover` rather than `Menu` so it can share
/// `TabPillLabel`'s pill background — `.menuStyle(.borderlessButton)` strips
/// custom label chrome on macOS.
struct SkillsPillMenu: View {
    let config: MeetingConfig
    let consoleViewModel: ConsoleViewModel
    var activeFilePath: String?
    var onConfigure: (() -> Void)?

    @State private var showMenu = false

    var body: some View {
        TabPillButton(
            label: "Skills",
            systemImage: "sparkles",
            active: showMenu,
            hasChevron: true,
            help: "Run a skill action",
            action: { showMenu.toggle() }
        )
        .popover(isPresented: $showMenu, arrowEdge: .bottom) {
            menuContent
                .frame(width: 300)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Skills for this meeting")
                .textCase(.uppercase)
                .font(.system(size: 9.5, weight: .bold))
                .kerning(0.85)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)

            ForEach(config.actions) { action in
                SkillsActionRow(action: action) {
                    runAction(action)
                }
            }

            if onConfigure != nil {
                Divider()
                    .padding(.top, 4)
            }

            if let onConfigure {
                SkillsConfigureRow {
                    onConfigure()
                    showMenu = false
                }
            }
        }
        .padding(5)
    }

    private func runAction(_ action: SkillAction) {
        let filePrefix = activeFilePath.map { $0 + " " } ?? ""
        let fullParameter = filePrefix + (action.parameter ?? "")
        consoleViewModel.sendSkill(
            filename: action.skillFilename,
            parameter: fullParameter.isEmpty ? nil : fullParameter
        )
        showMenu = false
    }
}

private struct SkillsActionRow: View {
    let action: SkillAction
    let onRun: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onRun) {
            HStack(spacing: 8) {
                Text(action.buttonName)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let parameter = action.parameter, !parameter.isEmpty {
                    Text(parameter)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.cyan.opacity(0.09))
                        }
                        .frame(maxWidth: 120, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if hovered {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cyan.opacity(0.14))
                }
            }
            .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct SkillsConfigureRow: View {
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text("Edit skills for this meeting")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if hovered {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                }
            }
            .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Transcript Pill (toggle)

/// Toggle pill switching between the markdown note and the recorded transcript.
struct TranscriptPill: View {
    let entry: MeetingDateEntry
    @Binding var showTranscripts: Bool

    var body: some View {
        let canToggle = entry.hasNote && entry.hasTranscript
        TabPillButton(
            label: "Transcript",
            systemImage: "waveform",
            active: showTranscripts,
            disabled: !canToggle,
            help: helpText(canToggle: canToggle),
            action: {
                withAnimation(.easeInOut(duration: 0.2)) { showTranscripts.toggle() }
            }
        )
    }

    private func helpText(canToggle: Bool) -> LocalizedStringKey {
        if !canToggle {
            return entry.hasNote ? "No transcript" : "No note"
        }
        return showTranscripts ? "Show notes" : "Show transcripts"
    }
}

// MARK: - Entry More Menu (small square)

/// Ellipsis "more" menu rendered as a small rounded square. Houses the
/// destructive entry-level actions (delete note / transcript / both).
struct EntryMoreMenu: View {
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
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .contentShape(.rect(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .help("More")
    }
}

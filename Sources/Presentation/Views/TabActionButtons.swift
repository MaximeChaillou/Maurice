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

/// Visual content of a small rounded square pill (24×24, secondary icon).
/// Used standalone inside `AppKitMenuButton` and as the label for
/// `TabSquareButton`.
struct TabSquareLabel: View {
    let systemImage: String

    var body: some View {
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
}

/// Small rounded square button used for ellipsis / icon-only actions in the toolbar.
struct TabSquareButton: View {
    let systemImage: String
    var help: LocalizedStringKey = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            TabSquareLabel(systemImage: systemImage)
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

// MARK: - AppKit Menu Button (right-aligned native NSMenu)

/// Native NSMenu that drops below a SwiftUI label, with its right edge
/// aligned to the label's right edge — so the menu extends leftward.
/// Use this for buttons near the right edge of the screen, where SwiftUI's
/// `Menu` (which always anchors to the leading edge on macOS) would push
/// the menu off-screen or cover the wrong area.
struct AppKitMenuButton: NSViewRepresentable {
    let entries: [AppKitMenuEntry]
    let label: AnyView

    init<L: View>(entries: [AppKitMenuEntry], @ViewBuilder label: () -> L) {
        self.entries = entries
        self.label = AnyView(label())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> AppKitMenuButtonView {
        AppKitMenuButtonView(coordinator: context.coordinator, label: label)
    }

    func updateNSView(_ nsView: AppKitMenuButtonView, context: Context) {
        context.coordinator.parent = self
        nsView.updateLabel(label)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: AppKitMenuButton

        init(parent: AppKitMenuButton) {
            self.parent = parent
        }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()
            for (index, entry) in parent.entries.enumerated() {
                switch entry {
                case .separator:
                    menu.addItem(.separator())
                case .item(let title, let systemImage, let isDestructive, _):
                    let item = NSMenuItem(
                        title: title,
                        action: #selector(menuItemSelected(_:)),
                        keyEquivalent: ""
                    )
                    item.target = self
                    item.tag = index
                    if let systemImage {
                        item.image = NSImage(
                            systemSymbolName: systemImage,
                            accessibilityDescription: nil
                        )
                    }
                    if isDestructive {
                        item.attributedTitle = NSAttributedString(
                            string: title,
                            attributes: [.foregroundColor: NSColor.systemRed]
                        )
                    }
                    menu.addItem(item)
                }
            }
            return menu
        }

        @objc private func menuItemSelected(_ sender: NSMenuItem) {
            guard sender.tag < parent.entries.count else { return }
            if case .item(_, _, _, let action) = parent.entries[sender.tag] {
                action()
            }
        }
    }
}

enum AppKitMenuEntry {
    case item(
        title: String,
        systemImage: String? = nil,
        isDestructive: Bool = false,
        action: () -> Void
    )
    case separator
}

final class AppKitMenuButtonView: NSView {
    fileprivate let coordinator: AppKitMenuButton.Coordinator
    private let hosting: NSHostingView<AnyView>

    init(coordinator: AppKitMenuButton.Coordinator, label: AnyView) {
        self.coordinator = coordinator
        self.hosting = NSHostingView(rootView: label)
        super.init(frame: .zero)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func updateLabel(_ label: AnyView) {
        hosting.rootView = label
    }

    override var intrinsicContentSize: NSSize {
        hosting.intrinsicContentSize
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        let menu = coordinator.makeMenu()
        menu.update()
        let menuWidth = menu.size.width > 0 ? menu.size.width : estimatedMenuWidth(menu)
        let bottomY = isFlipped ? bounds.maxY + 6 : bounds.minY - 6
        let origin = NSPoint(
            x: bounds.maxX - menuWidth,
            y: bottomY
        )
        menu.popUp(positioning: nil, at: origin, in: self)
    }

    private func estimatedMenuWidth(_ menu: NSMenu) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.menuFont(ofSize: 0)]
        var maxTitleWidth: CGFloat = 0
        for item in menu.items where !item.isSeparatorItem {
            let titleSize = (item.title as NSString).size(withAttributes: attrs)
            maxTitleWidth = max(maxTitleWidth, titleSize.width)
        }
        return maxTitleWidth + 28
    }
}

// MARK: - Skills Pill Menu

/// "Skills" pill that opens a right-aligned native NSMenu listing configured
/// skill actions plus a footer entry that opens the meeting config sheet.
struct SkillsPillMenu: View {
    let config: MeetingConfig
    let consoleViewModel: ConsoleViewModel
    var activeFilePath: String?
    var onConfigure: (() -> Void)?

    var body: some View {
        AppKitMenuButton(
            entries: Self.makeEntries(
                actions: config.actions,
                runAction: runAction,
                onConfigure: onConfigure
            )
        ) {
            TabPillLabel(
                label: "Skills",
                systemImage: "sparkles",
                hasChevron: true
            )
        }
        .fixedSize()
        .help("Run a skill action")
    }

    static func makeEntries(
        actions: [SkillAction],
        runAction: @escaping (SkillAction) -> Void,
        onConfigure: (() -> Void)?
    ) -> [AppKitMenuEntry] {
        var entries: [AppKitMenuEntry] = []
        for action in actions {
            let title: String
            if let parameter = action.parameter, !parameter.isEmpty {
                title = "\(action.buttonName) — \(parameter)"
            } else {
                title = action.buttonName
            }
            entries.append(.item(
                title: title,
                action: { runAction(action) }
            ))
        }
        if let onConfigure {
            if !entries.isEmpty {
                entries.append(.separator)
            }
            entries.append(.item(
                title: String(localized: "Edit skills for this meeting"),
                systemImage: "slider.horizontal.3",
                action: onConfigure
            ))
        }
        return entries
    }

    private func runAction(_ action: SkillAction) {
        let filePrefix = activeFilePath.map { $0 + " " } ?? ""
        let fullParameter = filePrefix + (action.parameter ?? "")
        consoleViewModel.sendSkill(
            filename: action.skillFilename,
            parameter: fullParameter.isEmpty ? nil : fullParameter
        )
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

/// Ellipsis "more" menu rendered as a small rounded square. Right-aligned
/// native NSMenu housing the destructive entry-level actions (delete note
/// / transcript / both).
struct EntryMoreMenu: View {
    let entry: MeetingDateEntry
    @Binding var entryDeleteAction: EntryDeleteAction?

    var body: some View {
        AppKitMenuButton(
            entries: Self.makeEntries(entry: entry) { action in
                entryDeleteAction = action
            }
        ) {
            TabSquareLabel(systemImage: "ellipsis")
        }
        .fixedSize()
        .help("More")
    }

    static func makeEntries(
        entry: MeetingDateEntry,
        delete: @escaping (EntryDeleteAction) -> Void
    ) -> [AppKitMenuEntry] {
        var entries: [AppKitMenuEntry] = []
        if entry.hasNote {
            entries.append(.item(
                title: String(localized: "Delete note"),
                systemImage: "doc.text",
                isDestructive: true,
                action: { delete(.note(entry)) }
            ))
        }
        if entry.hasTranscript {
            entries.append(.item(
                title: String(localized: "Delete transcript"),
                systemImage: "waveform",
                isDestructive: true,
                action: { delete(.transcript(entry)) }
            ))
        }
        if entry.hasNote && entry.hasTranscript {
            entries.append(.separator)
            entries.append(.item(
                title: String(localized: "Delete all"),
                systemImage: "trash",
                isDestructive: true,
                action: { delete(.both(entry)) }
            ))
        }
        return entries
    }
}

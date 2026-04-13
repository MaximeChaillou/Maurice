import SwiftUI

struct TemplateUpdatesView: View {
    let service: TemplateUpdateService
    let rootDirectory: URL
    @State private var selected: TemplateUpdateService.TemplateDescriptor?

    var body: some View {
        Group {
            if service.pendingTemplates.isEmpty {
                ContentUnavailableView(
                    "Templates up to date",
                    systemImage: "checkmark.seal",
                    description: Text(
                        "All skill templates match the latest bundled versions."
                    )
                )
            } else {
                HSplitView {
                    list
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { seedSelection() }
        .onChange(of: service.pendingTemplates) { _, _ in seedSelection() }
    }

    private func seedSelection() {
        if let current = selected,
           service.pendingTemplates.contains(where: { $0.id == current.id }) {
            return
        }
        selected = service.pendingTemplates.first
    }

    private var list: some View {
        List(selection: $selected) {
            Section {
                ForEach(service.pendingTemplates) { template in
                    HStack {
                        Text(template.name)
                        Spacer()
                        Circle().fill(.orange).frame(width: 7, height: 7)
                    }
                    .tag(template)
                }
            } header: {
                Text("New versions available")
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detail: some View {
        if let template = selected {
            TemplateDiffPane(
                template: template,
                service: service,
                rootDirectory: rootDirectory
            )
            .id(template.id)
        } else {
            ContentUnavailableView(
                "No template selected",
                systemImage: "doc.text"
            )
        }
    }
}

// MARK: - Diff pane

private enum TemplateHunkDecision: Hashable { case accept, keep }

private struct TemplateDiffPane: View {
    let template: TemplateUpdateService.TemplateDescriptor
    let service: TemplateUpdateService
    let rootDirectory: URL

    @State private var decisions: [Int: TemplateHunkDecision] = [:]

    private var rawLines: [TemplateDiffLine] {
        let bundledData = service.bundledData(for: template)
        let userTagged = TemplateUpdateService.taggedLines(
            of: service.userData(for: template), template: bundledData
        )
        let bundledTagged = TemplateUpdateService.taggedLines(
            of: bundledData, template: bundledData
        )
        return TemplateDiffComputer.unifiedDiff(old: userTagged, new: bundledTagged)
    }

    private var blocks: [TemplateDiffBlock] {
        TemplateDiffBlock.group(lines: rawLines)
    }

    private var hunkCount: Int {
        blocks.reduce(0) { $0 + ($1.isHunk ? 1 : 0) }
    }

    private var decidedCount: Int { decisions.count }
    private var undecidedCount: Int { max(hunkCount - decidedCount, 0) }
    private var acceptCount: Int { decisions.values.filter { $0 == .accept }.count }
    private var keepCount: Int { decisions.values.filter { $0 == .keep }.count }
    private var fileWillChange: Bool { acceptCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            decisionToolbar
            Divider()
            diffBody
            Divider()
            bulkFooter
        }
    }

    // MARK: - Header

    private var header: some View {
        Text(template.name)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    // MARK: - Body

    private var diffBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(for: block)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private func blockView(for block: TemplateDiffBlock) -> some View {
        switch block {
        case let .context(line):
            TemplateDiffLineRow(line: line)
        case let .hunk(hunk):
            TemplateHunkView(
                hunk: hunk,
                decision: decisions[hunk.id],
                onAccept: { decisions[hunk.id] = .accept },
                onKeep: { decisions[hunk.id] = .keep },
                onUndo: { decisions.removeValue(forKey: hunk.id) }
            )
        }
    }

    // MARK: - Decision toolbar (top)

    private var decisionToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusBanner
            HStack(spacing: 10) {
                decisionChip(
                    systemImage: "checkmark", count: acceptCount, tint: .green, label: "accepted"
                )
                decisionChip(
                    systemImage: "xmark", count: keepCount, tint: .secondary, label: "kept"
                )
                decisionChip(
                    systemImage: "circle.dotted", count: undecidedCount,
                    tint: .orange, label: "remaining"
                )
                Spacer()
                Button("Discard decisions") { decisions.removeAll() }
                    .disabled(decisions.isEmpty)
                Button("Apply", action: applyDecisions)
                    .buttonStyle(.borderedProminent)
                    .tint(undecidedCount > 0 ? .secondary : .accentColor)
                    .opacity(undecidedCount > 0 ? 0.5 : 1.0)
                    .disabled(undecidedCount > 0)
                    .help(undecidedCount > 0
                        ? String(localized: "Decide on all blocks before applying.")
                        : "")
            }
        }
        .padding(12)
    }

    // MARK: - Bulk footer (bottom)

    private var bulkFooter: some View {
        HStack {
            Spacer()
            Button("Keep my version") { keepAll() }
            Button("Use new version") { applyAll() }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }

    private func applyAll() {
        Task { await service.applyBundled(for: template, rootDirectory: rootDirectory) }
    }

    private func keepAll() {
        Task { await service.keepUser(for: template, rootDirectory: rootDirectory) }
    }

    @ViewBuilder
    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: bannerIcon).foregroundStyle(bannerTint)
            Text(bannerText)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var bannerIcon: String {
        if undecidedCount > 0 { return "exclamationmark.circle" }
        return fileWillChange ? "pencil.line" : "checkmark.circle"
    }

    private var bannerTint: Color {
        if undecidedCount > 0 { return .orange }
        return fileWillChange ? .orange : .green
    }

    private var bannerText: LocalizedStringKey {
        if undecidedCount > 0 {
            return "Decide on every block (Accept or Keep) to enable Apply."
        }
        if fileWillChange {
            return "Apply will rewrite your file to include \(acceptCount) accepted block(s)."
        }
        return "No file change pending. Apply only records that you reviewed this version."
    }

    private func decisionChip(
        systemImage: String, count: Int, tint: Color, label: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.caption2)
            Text("\(count)").font(.caption.bold().monospacedDigit())
            Text(label).font(.caption)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Actions

    private func applyDecisions() {
        let content = fileWillChange ? buildResolvedContent() : nil
        Task {
            await service.commit(
                for: template, content: content, rootDirectory: rootDirectory
            )
            decisions.removeAll()
        }
    }

    /// Produce the final user content from current decisions. Undecided hunks
    /// are implicitly "keep" (user's lines stay).
    private func buildResolvedContent() -> String {
        var lines: [String] = []
        for block in blocks {
            switch block {
            case let .context(line):
                lines.append(line.content)
            case let .hunk(hunk):
                switch decisions[hunk.id] {
                case .accept:
                    lines.append(contentsOf: hunk.addedLines)
                case .keep, .none:
                    lines.append(contentsOf: hunk.removedLines)
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - TemplateHunk view

private struct TemplateHunkView: View {
    let hunk: TemplateHunk
    let decision: TemplateHunkDecision?
    let onAccept: () -> Void
    let onKeep: () -> Void
    let onUndo: () -> Void

    @State private var hovering = false

    var body: some View {
        Group {
            switch decision {
            case .accept: decidedAccept
            case .keep: decidedKeep
            case .none: undecided
            }
        }
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
        .animation(.easeInOut(duration: 0.15), value: decision)
    }

    // MARK: Undecided

    private var undecided: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(hunk.removedLines.enumerated()), id: \.offset) { _, line in
                TemplateDiffLineRow(line: TemplateDiffLine(kind: .removed, content: line))
            }
            ForEach(Array(hunk.addedLines.enumerated()), id: \.offset) { _, line in
                TemplateDiffLineRow(line: TemplateDiffLine(kind: .added, content: line))
            }
        }
        .overlay(alignment: .topTrailing) {
            if hovering {
                HStack(spacing: 4) {
                    hoverButton(
                        "Keep", systemImage: "xmark", tint: .secondary, action: onKeep
                    )
                    hoverButton(
                        "Accept", systemImage: "checkmark", tint: .green, action: onAccept
                    )
                }
                .padding(4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .padding(6)
                .transition(.opacity)
            }
        }
    }

    // MARK: Decided

    private var decidedAccept: some View {
        decidedContainer(
            borderColor: .green,
            badge: "checkmark.circle.fill",
            badgeLabel: "Will use new version",
            badgeTint: .green
        ) {
            ForEach(Array(hunk.addedLines.enumerated()), id: \.offset) { _, line in
                TemplateDiffLineRow(line: TemplateDiffLine(kind: .added, content: line))
            }
        }
    }

    private var decidedKeep: some View {
        decidedContainer(
            borderColor: .secondary,
            badge: "xmark.circle.fill",
            badgeLabel: "Will keep your version",
            badgeTint: .secondary
        ) {
            ForEach(Array(hunk.removedLines.enumerated()), id: \.offset) { _, line in
                TemplateDiffLineRow(line: TemplateDiffLine(kind: .same, content: line))
            }
        }
    }

    private func decidedContainer<Content: View>(
        borderColor: Color,
        badge: String,
        badgeLabel: LocalizedStringKey,
        badgeTint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: badge).foregroundStyle(badgeTint)
                Text(badgeLabel).font(.caption.bold())
                Spacer()
                if hovering {
                    Button(action: onUndo) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.12), in: Capsule())
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            content()
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(borderColor.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
    }

    private func hoverButton(
        _ label: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

import SwiftUI

// MARK: - Header types

enum TabHeaderIcon {
    case emoji(String)
    case initials(String, gradient: [Color])
    case symbol(String)
}

struct TabMetaItem {
    let systemImage: String
    let label: String
    var tint: Color?
    /// When non-nil, the meta item is clickable and opens an inline TextField
    /// seeded with `editValue`. `onCommit` is invoked with the trimmed value.
    var editValue: String?
    var placeholder: String?
    var onCommit: ((String) -> Void)?
    /// When `true`, render as a green/red capsule with a status dot in display
    /// mode (the editor still uses the regular inline TextField). Pairs with
    /// an editable meta item: present `editValue` ⇒ ok (green), empty ⇒ err
    /// (red).
    var isStatus: Bool

    init(
        systemImage: String,
        label: String,
        tint: Color? = nil,
        editValue: String? = nil,
        placeholder: String? = nil,
        onCommit: ((String) -> Void)? = nil,
        isStatus: Bool = false
    ) {
        self.systemImage = systemImage
        self.label = label
        self.tint = tint
        self.editValue = editValue
        self.placeholder = placeholder
        self.onCommit = onCommit
        self.isStatus = isStatus
    }

    var isEditable: Bool { onCommit != nil }

    /// Shared "Google Calendar linked / not linked" status pill, editable
    /// inline. Used by Meetings (folder config) and People (1-1 config).
    static func googleCalendarStatus(
        config: Binding<MeetingConfig>,
        configURL: URL
    ) -> TabMetaItem {
        let linked = !(config.wrappedValue.calendarEventName?.isEmpty ?? true)
        return TabMetaItem(
            systemImage: "calendar",
            label: linked
                ? String(localized: "Google Calendar linked")
                : String(localized: "Google Calendar not linked"),
            editValue: config.wrappedValue.calendarEventName ?? "",
            placeholder: String(localized: "Event name"),
            onCommit: { newValue in
                config.wrappedValue.calendarEventName = newValue.isEmpty ? nil : newValue
                MeetingConfigStore.shared.update(config.wrappedValue, for: configURL)
            },
            isStatus: true
        )
    }
}

/// Status capsule colors lifted directly from the design tokens
/// (`Dir2MetaEditable`'s ok/err palette, harmonised with the teal accent).
private struct MetaStatusColors {
    let foreground: Color
    let background: Color
    let dot: Color

    static func resolve(linked: Bool, scheme: ColorScheme) -> MetaStatusColors {
        switch (linked, scheme) {
        case (true, .dark):
            let base = Color(red: 95/255, green: 217/255, blue: 164/255)
            return .init(foreground: base, background: base.opacity(0.16), dot: base)
        case (true, _):
            let base = Color(red: 13/255, green: 138/255, blue: 94/255)
            return .init(foreground: base, background: base.opacity(0.10), dot: base)
        case (false, .dark):
            let base = Color(red: 240/255, green: 133/255, blue: 122/255)
            return .init(foreground: base, background: base.opacity(0.14), dot: base)
        case (false, _):
            let base = Color(red: 194/255, green: 72/255, blue: 58/255)
            return .init(foreground: base, background: base.opacity(0.08), dot: base)
        }
    }
}

// MARK: - Tab Doc Header

struct TabDocHeader<Trailing: View>: View {
    let icon: TabHeaderIcon
    let title: String
    var statusLabel: String?
    var statusAccent: Bool = false
    var dateLabel: String?
    var metaItems: [TabMetaItem] = []
    var onIconChange: ((String) -> Void)?
    var onTitleChange: ((String) -> Void)?
    @ViewBuilder var trailingActions: () -> Trailing

    @State private var iconText: String = ""
    @FocusState private var iconFieldFocused: Bool
    @State private var editingTitle = false
    @State private var titleDraft = ""
    @FocusState private var titleFieldFocused: Bool
    @State private var editingMetaIndex: Int?
    @State private var metaDraft: String = ""
    @FocusState private var metaFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusRow
            titleRow
            metaRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private var statusRow: some View {
        if statusLabel != nil || dateLabel != nil {
            HStack(spacing: 10) {
                if let statusLabel {
                    StatusPill(label: statusLabel, accent: statusAccent)
                }
                if let dateLabel {
                    Text(dateLabel)
                        .font(.system(size: 11.5))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            iconView
            titleView
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if editingTitle, let onTitleChange {
            titleEditor(onChange: onTitleChange)
        } else {
            titleDisplay
        }
    }

    private func titleEditor(onChange: @escaping (String) -> Void) -> some View {
        TextField("", text: $titleDraft)
            .textFieldStyle(.plain)
            .focused($titleFieldFocused)
            .font(.system(size: 22, weight: .semibold))
            .tracking(-0.3)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cyan.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.cyan.opacity(0.4), lineWidth: 0.5)
                    }
            }
            .onSubmit { commitTitle(onChange: onChange) }
            .onChange(of: titleFieldFocused) {
                if !titleFieldFocused { commitTitle(onChange: onChange) }
            }
    }

    private var titleDisplay: some View {
        Text(title)
            .font(.system(size: 22, weight: .semibold))
            .tracking(-0.3)
            .lineLimit(1)
            .padding(.horizontal, onTitleChange != nil ? 6 : 0)
            .padding(.vertical, onTitleChange != nil ? 1 : 0)
            .contentShape(.rect(cornerRadius: 6))
            .onTapGesture {
                guard onTitleChange != nil else { return }
                titleDraft = title
                editingTitle = true
                DispatchQueue.main.async { titleFieldFocused = true }
            }
            .help(onTitleChange != nil ? "Click to rename" : "")
    }

    private func commitTitle(onChange: (String) -> Void) {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != title {
            onChange(trimmed)
        }
        editingTitle = false
    }

    @ViewBuilder
    private var metaRow: some View {
        if !metaItems.isEmpty || hasTrailingActions {
            HStack(spacing: 10) {
                ForEach(Array(metaItems.enumerated()), id: \.offset) { idx, item in
                    if idx > 0 {
                        Circle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 3, height: 3)
                    }
                    metaItemView(idx: idx, item: item)
                }
                Spacer(minLength: 8)
                trailingActions()
            }
        }
    }

    private var hasTrailingActions: Bool { Trailing.self != EmptyView.self }

    @ViewBuilder
    private func metaItemView(idx: Int, item: TabMetaItem) -> some View {
        if editingMetaIndex == idx, let onCommit = item.onCommit {
            metaItemEditor(item: item, onCommit: onCommit)
        } else if item.isStatus {
            MetaStatusCapsule(item: item) { beginEditing(idx: idx, item: item) }
        } else {
            metaItemDisplay(idx: idx, item: item)
        }
    }

    private func metaItemDisplay(idx: Int, item: TabMetaItem) -> some View {
        let isFaint = item.isEditable && (item.editValue?.isEmpty ?? true)
        let foreground: AnyShapeStyle = {
            if let tint = item.tint { return AnyShapeStyle(tint) }
            return isFaint
                ? AnyShapeStyle(HierarchicalShapeStyle.tertiary)
                : AnyShapeStyle(HierarchicalShapeStyle.secondary)
        }()
        return HStack(spacing: 5) {
            Image(systemName: item.systemImage)
                .font(.system(size: 11, weight: .medium))
            Text(item.label)
                .font(.system(size: 11.5))
                .italic(isFaint)
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, item.isEditable ? 5 : 0)
        .padding(.vertical, item.isEditable ? 1 : 0)
        .contentShape(.rect(cornerRadius: 5))
        .onTapGesture {
            guard item.isEditable else { return }
            beginEditing(idx: idx, item: item)
        }
        .help(item.isEditable ? "Click to edit" : "")
    }

    private func beginEditing(idx: Int, item: TabMetaItem) {
        metaDraft = item.editValue ?? ""
        editingMetaIndex = idx
        DispatchQueue.main.async { metaFieldFocused = true }
    }

    private func metaItemEditor(item: TabMetaItem, onCommit: @escaping (String) -> Void) -> some View {
        HStack(spacing: 5) {
            Image(systemName: item.systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(item.placeholder ?? "", text: $metaDraft)
                .textFieldStyle(.plain)
                .focused($metaFieldFocused)
                .font(.system(size: 11.5))
                .frame(minWidth: 160)
                .onSubmit { commitMeta(onCommit: onCommit) }
                .onExitCommand { cancelMeta() }
                .onChange(of: metaFieldFocused) {
                    if !metaFieldFocused { commitMeta(onCommit: onCommit) }
                }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.cyan.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.cyan.opacity(0.4), lineWidth: 0.5)
                }
        }
    }

    private func commitMeta(onCommit: (String) -> Void) {
        let trimmed = metaDraft.trimmingCharacters(in: .whitespaces)
        onCommit(trimmed)
        editingMetaIndex = nil
    }

    private func cancelMeta() {
        editingMetaIndex = nil
    }

    @ViewBuilder
    private var iconView: some View {
        if let onIconChange {
            Button {
                triggerIconPicker(onChange: onIconChange)
            } label: {
                ZStack {
                    iconContent
                    TextField("", text: $iconText)
                        .focused($iconFieldFocused)
                        .opacity(0)
                        .frame(width: 1, height: 1)
                        .onChange(of: iconText) {
                            handleIconInput(onChange: onIconChange)
                        }
                }
                .frame(width: 32, height: 32)
                .contentShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Click to change icon")
        } else {
            iconContent.frame(width: 32, height: 32)
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch icon {
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: 24))
        case .initials(let initials, let gradient):
            Text(initials)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                        }
                }
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }

    private func triggerIconPicker(onChange: (String) -> Void) {
        iconFieldFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.orderFrontCharacterPalette(nil)
        }
    }

    private func handleIconInput(onChange: (String) -> Void) {
        guard let last = iconText.last else { return }
        let single = String(last)
        if single != iconText { iconText = single }
        onChange(single)
        iconText = ""
        iconFieldFocused = false
    }
}

extension TabDocHeader where Trailing == EmptyView {
    init(
        icon: TabHeaderIcon,
        title: String,
        statusLabel: String? = nil,
        statusAccent: Bool = false,
        dateLabel: String? = nil,
        metaItems: [TabMetaItem] = [],
        onIconChange: ((String) -> Void)? = nil,
        onTitleChange: ((String) -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.statusLabel = statusLabel
        self.statusAccent = statusAccent
        self.dateLabel = dateLabel
        self.metaItems = metaItems
        self.onIconChange = onIconChange
        self.onTitleChange = onTitleChange
        self.trailingActions = { EmptyView() }
    }
}

// MARK: - Meta Status Capsule

/// Capsule rendering for a status-style editable meta item — colored dot +
/// label, green when linked / red when not linked. Tap to start editing.
private struct MetaStatusCapsule: View {
    let item: TabMetaItem
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        let linked = !(item.editValue?.isEmpty ?? true)
        let palette = MetaStatusColors.resolve(linked: linked, scheme: colorScheme)
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(palette.dot)
                    .frame(width: 6, height: 6)
                Text(item.label)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(palette.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(palette.background.opacity(hovered ? 1.5 : 1))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(item.isEditable ? "Click to edit" : "")
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let label: String
    let accent: Bool
    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9.5, weight: .bold))
            .kerning(0.7)
            .foregroundStyle(accent ? Color.cyan : Color.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(accent ? Color.cyan.opacity(0.14) : Color.primary.opacity(0.06))
            }
    }
}

import SwiftUI

/// Skills management sheet for a meeting / 1-1.
/// Matches the `Dir2SkillsConfigSheet` design exactly: header with target
/// emoji + "SKILLS · <name>" label + close, configured-skills container, then
/// the available-library section, then a single "Terminé" footer button.
struct MeetingConfigSheet: View {
    let folderName: String
    let folderURL: URL
    @Binding var config: MeetingConfig
    var consoleViewModel: ConsoleViewModel

    @State private var availableSkills: [SkillFile] = []
    @State private var localActions: [SkillAction] = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            ScrollView {
                MeetingSkillsSection(
                    actions: $localActions,
                    availableSkills: availableSkills
                )
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            Divider().opacity(0.6)
            footer
        }
        .onAppear {
            localActions = config.actions
            Task {
                availableSkills = await MeetingSkillConfig.availableSkillsAsync()
            }
        }
        .onChange(of: localActions) {
            config.actions = localActions
            MeetingConfigStore.shared.update(config, for: folderURL)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("🎯")
                .font(.system(size: 20))
            Text("Skills · \(folderName)")
                .font(.system(size: 10.5, weight: .semibold))
                .kerning(0.85)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background {
                        Circle().fill(Color.primary.opacity(0.06))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.cyan.opacity(0.16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Skills section

/// Manages the list of `SkillAction`s configured for a meeting / 1-1.
///
/// Layout matches the design: an accent-bordered container listing the
/// configured actions on top, then a flat library list of available skills
/// (from `.claude/commands`) that haven't been added yet. Hover reveals
/// inline `Renommer` / `Retirer` controls on configured rows and `Ajouter`
/// on library rows.
struct MeetingSkillsSection: View {
    @Binding var actions: [SkillAction]
    let availableSkills: [SkillFile]

    private var libraryAvailable: [SkillFile] {
        let configuredFilenames = Set(actions.map(\.skillFilename))
        return availableSkills.filter { !configuredFilenames.contains($0.filename) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            configuredContainer
            if !libraryAvailable.isEmpty {
                librarySection
            }
        }
    }

    // MARK: Configured container

    private var configuredContainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: String(localized: "Skills for this meeting"),
                count: actions.count
            )

            if actions.isEmpty {
                Text("No configured skills")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach($actions) { $action in
                        ConfiguredSkillRow(
                            action: $action,
                            onRemove: { remove(action.id) }
                        )
                    }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cyan.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 0.5)
                }
        }
    }

    // MARK: Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(title: String(localized: "Available in library"), count: nil)
            VStack(spacing: 0) {
                ForEach(libraryAvailable) { skill in
                    LibrarySkillRow(skill: skill) {
                        addFromLibrary(skill)
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .kerning(1)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background {
                        Capsule().fill(Color.primary.opacity(0.06))
                    }
            }
        }
    }

    // MARK: Mutations

    private func remove(_ id: UUID) {
        actions.removeAll { $0.id == id }
    }

    private func addFromLibrary(_ skill: SkillFile) {
        let buttonName = Self.defaultButtonName(forFilename: skill.filename)
        actions.append(SkillAction(buttonName: buttonName, skillFilename: skill.filename))
    }

    /// Default button name when adding a library skill — filename without
    /// the `.md` extension and with dashes replaced by spaces.
    static func defaultButtonName(forFilename filename: String) -> String {
        let stem = filename.hasSuffix(".md")
            ? String(filename.dropLast(3))
            : filename
        return stem.replacingOccurrences(of: "-", with: " ")
    }
}

// MARK: - Configured skill row

private struct ConfiguredSkillRow: View {
    @Binding var action: SkillAction
    var onRemove: () -> Void

    @State private var hovered = false
    @State private var editing: EditingField?
    @State private var nameDraft: String = ""
    @State private var paramDraft: String = ""
    @FocusState private var focusedField: EditingField?

    private enum EditingField: Hashable { case name, parameter }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                titleView
                Text(action.skillFilename)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                parameterView
                    .padding(.top, 3)
            }
            Spacer(minLength: 4)
            if editing == nil {
                hoverActions
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.04))
        }
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private var titleView: some View {
        if editing == .name {
            TextField("", text: $nameDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($focusedField, equals: .name)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.cyan.opacity(0.45), lineWidth: 0.5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
                }
                .onSubmit { commitName() }
                .onExitCommand { cancelName() }
        } else {
            Text(action.buttonName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var parameterView: some View {
        if editing == .parameter {
            TextField("--option=value", text: $paramDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .focused($focusedField, equals: .parameter)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.cyan.opacity(0.45), lineWidth: 0.5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
                }
                .onSubmit { commitParameter() }
                .onExitCommand { cancelParameter() }
        } else if let parameter = action.parameter, !parameter.isEmpty {
            Button {
                beginEditingParameter()
            } label: {
                Text(parameter)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.cyan)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cyan.opacity(0.09))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.cyan.opacity(0.25), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(.plain)
            .help("Edit parameter")
        } else {
            Button {
                beginEditingParameter()
            } label: {
                Text("+ parameter")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: 4) {
            HoverPillButton(label: "Rename") { beginEditingName() }
            HoverPillButton(label: "Remove", action: onRemove)
        }
        .opacity(hovered ? 1 : 0)
        .animation(.easeOut(duration: 0.1), value: hovered)
    }

    private func beginEditingName() {
        nameDraft = action.buttonName
        editing = .name
        DispatchQueue.main.async { focusedField = .name }
    }

    private func commitName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            action.buttonName = trimmed
        }
        editing = nil
        focusedField = nil
    }

    private func cancelName() {
        nameDraft = action.buttonName
        editing = nil
        focusedField = nil
    }

    private func beginEditingParameter() {
        paramDraft = action.parameter ?? ""
        editing = .parameter
        DispatchQueue.main.async { focusedField = .parameter }
    }

    private func commitParameter() {
        let trimmed = paramDraft.trimmingCharacters(in: .whitespaces)
        action.parameter = trimmed.isEmpty ? nil : trimmed
        editing = nil
        focusedField = nil
    }

    private func cancelParameter() {
        paramDraft = action.parameter ?? ""
        editing = nil
        focusedField = nil
    }
}

// MARK: - Library skill row

private struct LibrarySkillRow: View {
    let skill: SkillFile
    let onAdd: () -> Void

    @State private var hovered = false

    private var displayName: String {
        skill.filename.hasSuffix(".md")
            ? String(skill.filename.dropLast(3))
            : skill.filename
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(displayName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            HoverPillButton(label: "Add", isAccent: true, action: onAdd)
                .opacity(hovered ? 1 : 0)
                .animation(.easeOut(duration: 0.1), value: hovered)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
        }
        .contentShape(.rect)
        .onHover { hovered = $0 }
    }
}

// MARK: - Hover pill button

private struct HoverPillButton: View {
    let label: LocalizedStringKey
    var isAccent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: isAccent ? .semibold : .medium))
                .foregroundStyle(isAccent ? Color.cyan : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isAccent ? Color.cyan.opacity(0.14) : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    isAccent ? Color.cyan.opacity(0.3) : Color.primary.opacity(0.12),
                                    lineWidth: 0.5
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

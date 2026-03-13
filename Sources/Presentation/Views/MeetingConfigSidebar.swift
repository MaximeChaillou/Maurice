import SwiftUI

struct MeetingConfigSidebar: View {
    let folderName: String
    @Binding var config: MeetingSkillConfig
    var runner: SkillRunner

    @State private var availableSkills: [SkillFile] = []
    @State private var isAddingAction = false
    @State private var editingAction: SkillAction?
    @State private var formName = ""
    @State private var formSkill: String?

    private var actions: [SkillAction] {
        config.actions(for: folderName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            List {
                actionsSection

                if isAddingAction || editingAction != nil {
                    Section {
                        actionForm
                    }
                }
            }
            .listStyle(.sidebar)

            Spacer(minLength: 0)

            if !isAddingAction && editingAction == nil {
                addActionButton
            }
        }
        .frame(width: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .onAppear { availableSkills = MeetingSkillConfig.availableSkills() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Configuration")
                .font(.headline)
            Text(folderName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    // MARK: - Actions list

    private var actionsSection: some View {
        Section("Actions") {
            ForEach(actions) { action in
                actionRow(action)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            config.removeAction(id: action.id, from: folderName)
                            config.save()
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }

                        Button {
                            editingAction = action
                            formName = action.buttonName
                            formSkill = action.skillFilename
                            isAddingAction = false
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
            }
        }
    }

    private func actionRow(_ action: SkillAction) -> some View {
        ActionRowView(
            action: action,
            isRunning: runner.isRunning && runner.actionID == action.id
        ) {
            guard !runner.isRunning else { return }
            runner.actionID = action.id
            runner.run(
                skillFilename: action.skillFilename,
                buttonName: action.buttonName,
                workingDirectory: AppSettings.rootDirectory
            )
        }
    }

    // MARK: - Action form (add / edit)

    private var formTitle: String {
        editingAction != nil ? "Modifier l'action" : "Nouvelle action"
    }

    private var actionForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Nom du bouton", text: $formName)
                .textFieldStyle(.roundedBorder)

            Picker("Skill", selection: $formSkill) {
                Text("Choisir un skill…")
                    .tag(nil as String?)
                ForEach(availableSkills) { skill in
                    Text(skill.name)
                        .tag(skill.filename as String?)
                }
            }

            HStack {
                Button("Annuler") {
                    resetForm()
                }

                Spacer()

                Button(editingAction != nil ? "Enregistrer" : "Ajouter") {
                    guard let skill = formSkill, !formName.isEmpty else { return }
                    if let existing = editingAction {
                        config.updateAction(id: existing.id, buttonName: formName, skillFilename: skill, in: folderName)
                    } else {
                        let action = SkillAction(buttonName: formName, skillFilename: skill)
                        config.addAction(action, to: folderName)
                    }
                    config.save()
                    resetForm()
                }
                .disabled(formSkill == nil || formName.isEmpty)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Add button

    private var addActionButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                editingAction = nil
                formName = ""
                formSkill = nil
                isAddingAction = true
            } label: {
                Label("Ajouter une action", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(12)
        }
    }

    private func resetForm() {
        formName = ""
        formSkill = nil
        isAddingAction = false
        editingAction = nil
    }
}

// MARK: - Action row with hover

private struct ActionRowView: View {
    let action: SkillAction
    let isRunning: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }

                Text(action.buttonName)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .disabled(isRunning)
        .help(action.skillFilename)
    }
}

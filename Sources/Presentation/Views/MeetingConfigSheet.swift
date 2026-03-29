import SwiftUI

struct MeetingConfigSheet: View {
    let folderName: String
    let folderURL: URL
    @Binding var config: MeetingConfig
    var consoleViewModel: ConsoleViewModel
    var onRename: ((String) -> Void)?

    @State private var availableSkills: [SkillFile] = []
    @State private var isAddingAction = false
    @State private var editingAction: SkillAction?
    @State private var formName = ""
    @State private var formSkill: String?
    @State private var formParameter = ""
    @State private var actionToDelete: SkillAction?

    // Local copies of config fields
    @State private var editedName: String = ""
    @State private var iconText: String = ""
    @State private var calendarText: String = ""
    @State private var localActions: [SkillAction] = []

    @FocusState private var iconFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var showActionSheet: Bool {
        isAddingAction || editingAction != nil
    }

    private var hasChanges: Bool {
        let nameChanged = editedName.trimmingCharacters(in: .whitespaces) != folderName
        let iconChanged = (iconText.isEmpty ? nil : iconText) != config.icon
        let calTrimmed = calendarText.trimmingCharacters(in: .whitespaces)
        let calChanged = (calTrimmed.isEmpty ? nil : calTrimmed) != config.calendarEventName
        let actionsChanged = localActions != config.actions
        return nameChanged || iconChanged || calChanged || actionsChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Configuration")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                Form {
                    meetingSection
                    calendarLinkSection
                    actionsSection
                }
                .formStyle(.grouped)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .onAppear {
            editedName = folderName
            iconText = config.icon ?? ""
            calendarText = config.calendarEventName ?? ""
            localActions = config.actions
            Task {
                availableSkills = await MeetingSkillConfig.availableSkillsAsync()
            }
        }
        .sheet(isPresented: Binding(
            get: { showActionSheet },
            set: { if !$0 { resetForm() } }
        )) {
            actionFormSheet
        }
    }

    // MARK: - Save

    private func save() {
        // Rename folder if needed
        let trimmedName = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty, trimmedName != folderName {
            onRename?(trimmedName)
        }

        // Update config
        config.icon = iconText.isEmpty ? nil : iconText
        let calTrimmed = calendarText.trimmingCharacters(in: .whitespaces)
        config.calendarEventName = calTrimmed.isEmpty ? nil : calTrimmed
        config.actions = localActions
        config.saveAsync(to: folderURL)

        dismiss()
    }

    // MARK: - Meeting name

    private var meetingSection: some View {
        Section("Meeting") {
            LabeledContent {
                HStack(spacing: 6) {
                    Button {
                        iconFieldFocused = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NSApp.orderFrontCharacterPalette(nil)
                        }
                    } label: {
                        ZStack {
                            Text(iconText.isEmpty ? "📁" : iconText)
                                .font(.title3)

                            TextField("", text: $iconText)
                                .focused($iconFieldFocused)
                                .opacity(0)
                                .frame(width: 1, height: 1)
                                .onChange(of: iconText) {
                                    if let last = iconText.last {
                                        let single = String(last)
                                        if single != iconText { iconText = single }
                                    }
                                    if !iconText.isEmpty {
                                        iconFieldFocused = false
                                    }
                                }
                        }
                        .frame(width: 28, height: 28)
                        .background(.quaternary, in: .rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Choose an icon")

                    TextField("", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                }
            } label: {
                Text("Name")
            }
        }
    }

    // MARK: - Calendar link

    private var calendarLinkSection: some View {
        Section("Linked Google Calendar event") {
            TextField("Event name", text: $calendarText)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            if localActions.isEmpty {
                Text("No configured actions")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(localActions) { action in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.buttonName)
                                .lineLimit(1)
                            if let param = action.parameter, !param.isEmpty {
                                Text(param)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            editingAction = action
                            formName = action.buttonName
                            formSkill = action.skillFilename
                            formParameter = action.parameter ?? ""
                            isAddingAction = false
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            actionToDelete = action
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            HStack {
                Text("Actions")
                Spacer()
                Button {
                    editingAction = nil
                    formName = ""
                    formSkill = nil
                    formParameter = ""
                    isAddingAction = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
        }
        .alert(
            "Delete action?",
            isPresented: Binding(
                get: { actionToDelete != nil },
                set: { if !$0 { actionToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { actionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let action = actionToDelete {
                    localActions.removeAll { $0.id == action.id }
                    actionToDelete = nil
                }
            }
        } message: {
            if let action = actionToDelete {
                Text(String(localized: "The action '\(action.buttonName)' will be deleted."))
            }
        }
    }

    // MARK: - Action form sheet

    private var formTitle: LocalizedStringKey {
        editingAction != nil ? "Edit action" : "New action"
    }

    private var actionFormSheet: some View {
        ActionFormSheet(
            title: formTitle,
            name: $formName,
            skill: $formSkill,
            parameter: $formParameter,
            availableSkills: availableSkills,
            saveLabel: editingAction != nil ? "Save" : "Add",
            onCancel: { resetForm() },
            onSave: { action in
                if let existing = editingAction {
                    if let idx = localActions.firstIndex(where: { $0.id == existing.id }) {
                        localActions[idx] = SkillAction(
                            id: existing.id, buttonName: action.buttonName,
                            skillFilename: action.skillFilename, parameter: action.parameter
                        )
                    }
                } else {
                    localActions.append(action)
                }
                resetForm()
            }
        )
    }

    private func resetForm() {
        formName = ""
        formSkill = nil
        formParameter = ""
        isAddingAction = false
        editingAction = nil
    }
}

// MARK: - Reusable Action Form

struct ActionFormSheet: View {
    var title: LocalizedStringKey = "New action"
    @Binding var name: String
    @Binding var skill: String?
    @Binding var parameter: String
    var availableSkills: [SkillFile]
    var saveLabel: LocalizedStringKey = "Add"
    var onCancel: () -> Void
    var onSave: (SkillAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField("Button name", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Skill", selection: $skill) {
                Text("Choose a skill...")
                    .tag(nil as String?)
                ForEach(availableSkills) { s in
                    Text(s.name)
                        .tag(s.filename as String?)
                }
            }

            TextField("Parameter (optional)", text: $parameter)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(saveLabel) {
                    guard let skill, !name.isEmpty else { return }
                    let param = parameter.trimmingCharacters(in: .whitespaces)
                    onSave(SkillAction(
                        buttonName: name,
                        skillFilename: skill,
                        parameter: param.isEmpty ? nil : param
                    ))
                }
                .disabled(skill == nil || name.isEmpty)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

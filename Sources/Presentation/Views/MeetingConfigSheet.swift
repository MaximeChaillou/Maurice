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
        VStack(alignment: .leading, spacing: 12) {
            Text(formTitle)
                .font(.headline)

            TextField("Button name", text: $formName)
                .textFieldStyle(.roundedBorder)

            Picker("Skill", selection: $formSkill) {
                Text("Choose a skill...")
                    .tag(nil as String?)
                ForEach(availableSkills) { skill in
                    Text(skill.name)
                        .tag(skill.filename as String?)
                }
            }

            TextField("Parameter (optional)", text: $formParameter)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    resetForm()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(editingAction != nil ? "Save" : "Add") {
                    guard let skill = formSkill, !formName.isEmpty else { return }
                    let param = formParameter.trimmingCharacters(in: .whitespaces)
                    let paramValue: String? = param.isEmpty ? nil : param
                    if let existing = editingAction {
                        if let idx = localActions.firstIndex(where: { $0.id == existing.id }) {
                            localActions[idx] = SkillAction(
                                id: existing.id, buttonName: formName,
                                skillFilename: skill, parameter: paramValue
                            )
                        }
                    } else {
                        localActions.append(
                            SkillAction(buttonName: formName, skillFilename: skill, parameter: paramValue)
                        )
                    }
                    resetForm()
                }
                .disabled(formSkill == nil || formName.isEmpty)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func resetForm() {
        formName = ""
        formSkill = nil
        formParameter = ""
        isAddingAction = false
        editingAction = nil
    }
}

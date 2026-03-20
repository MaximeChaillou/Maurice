import SwiftUI

struct SkillsSettingsView: View {
    var markdownTheme: MarkdownTheme

    @State private var skills: [SkillFile] = []
    @State private var selectedSkill: SkillFile?
    @State private var editorContent = ""
    @State private var isAddingSkill = false
    @State private var newSkillName = ""
    @State private var skillToDelete: SkillFile?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            skillList
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            skillDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { loadSkills() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .alert(
            "Delete skill?",
            isPresented: Binding(
                get: { skillToDelete != nil },
                set: { if !$0 { skillToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                skillToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let skill = skillToDelete {
                    deleteSkill(skill)
                }
            }
        } message: {
            if let skill = skillToDelete {
                Text(String(localized: "The file '\(skill.filename)' will be permanently deleted."))
            }
        }
    }

    // MARK: - List

    private var skillList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSkill) {
                ForEach(skills) { skill in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(skill.name)
                            .lineLimit(1)
                        Text(skill.filename)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(skill)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            skillToDelete = skill
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            if isAddingSkill {
                newSkillForm
            } else {
                Button {
                    isAddingSkill = true
                    newSkillName = ""
                } label: {
                    Label("Add a skill", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(12)
            }
        }
        .onChange(of: selectedSkill) {
            if let skill = selectedSkill {
                let url = skill.url
                Task {
                    let text = await Task.detached {
                        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                    }.value
                    editorContent = text
                }
            }
        }
    }

    // MARK: - New skill form

    private var newSkillForm: some View {
        VStack(spacing: 8) {
            TextField("Skill name (e.g. my-skill)", text: $newSkillName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isAddingSkill = false
                    newSkillName = ""
                }

                Spacer()

                Button("Create") {
                    createSkill()
                }
                .disabled(newSkillName.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
    }

    // MARK: - Detail

    @ViewBuilder
    private var skillDetail: some View {
        if selectedSkill != nil {
            VStack(spacing: 0) {
                Text("A skill is a Markdown prompt executed by AI on your notes. Example: summarize a transcript, extract actions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                ThemedMarkdownView(content: $editorContent, theme: markdownTheme)
            }
            .onChange(of: editorContent) {
                if let skill = selectedSkill {
                    let text = editorContent
                    let url = skill.url
                    let errorMessage = $errorMessage
                    Task.detached {
                        do {
                            try Data(text.utf8).write(to: url, options: .atomic)
                        } catch {
                            await MainActor.run {
                                errorMessage.wrappedValue = String(localized: "Unable to save: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        } else if skills.isEmpty {
            ContentUnavailableView(
                "No skills",
                systemImage: "terminal",
                description: Text(
                    "Skills are reusable AI prompts." +
                    " Create one to automate your tasks (summary, meeting notes...)."
                )
            )
        } else {
            ContentUnavailableView(
                "No skill selected",
                systemImage: "terminal",
                description: Text("Select a skill to edit it.")
            )
        }
    }

    // MARK: - Actions

    private func loadSkills() {
        Task {
            let result = await MeetingSkillConfig.availableSkillsAsync()
            skills = result
        }
    }

    private func createSkill() {
        var name = newSkillName.trimmingCharacters(in: .whitespaces)
        if !name.hasSuffix(".md") { name += ".md" }

        let dir = AppSettings.claudeCommandsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)

        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? Data("".utf8).write(to: url, options: .atomic)

        isAddingSkill = false
        newSkillName = ""
        loadSkills()

        selectedSkill = skills.first { $0.filename == name }
    }

    private func deleteSkill(_ skill: SkillFile) {
        do {
            try FileManager.default.removeItem(at: skill.url)
        } catch {
            errorMessage = String(localized: "Unable to delete '\(skill.name)': \(error.localizedDescription)")
        }
        if selectedSkill == skill { selectedSkill = nil }
        skillToDelete = nil
        loadSkills()
    }
}

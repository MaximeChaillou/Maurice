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
        .sheet(isPresented: $isAddingSkill) {
            AddItemSheet(
                title: "New skill",
                placeholder: "Skill name (e.g. my-skill)",
                text: $newSkillName,
                onCreate: { createSkill() },
                onCancel: { newSkillName = "" }
            )
        }
        .onChange(of: selectedSkill) {
            if let skill = selectedSkill {
                let url = skill.url
                Task {
                    let text = await Task.detached {
                        do {
                            return try String(contentsOf: url, encoding: .utf8)
                        } catch {
                            IssueLogger.log(.warning, "Failed to read skill file", context: url.path, error: error)
                            return ""
                        }
                    }.value
                    editorContent = text
                }
            }
        }
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
                            IssueLogger.log(.error, "Failed to save skill", context: url.path, error: error)
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
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            IssueLogger.log(.error, "Failed to create skills directory", context: dir.path, error: error)
        }
        let url = dir.appendingPathComponent(name)

        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try Data("".utf8).write(to: url, options: .atomic)
        } catch {
            IssueLogger.log(.error, "Failed to create skill file", context: url.path, error: error)
        }

        isAddingSkill = false
        newSkillName = ""
        loadSkills()

        selectedSkill = skills.first { $0.filename == name }
    }

    private func deleteSkill(_ skill: SkillFile) {
        do {
            try FileManager.default.removeItem(at: skill.url)
        } catch {
            IssueLogger.log(.error, "Failed to delete skill", context: skill.url.path, error: error)
            errorMessage = String(localized: "Unable to delete '\(skill.name)': \(error.localizedDescription)")
        }
        if selectedSkill == skill { selectedSkill = nil }
        skillToDelete = nil
        loadSkills()
    }
}

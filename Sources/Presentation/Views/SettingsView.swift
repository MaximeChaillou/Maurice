import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case calendar
    case background
    case appearance
    case skills
    case mcp
    case claudeMD

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .general: String(localized: "General")
        case .calendar: String(localized: "Google Calendar")
        case .background: String(localized: "Background")
        case .appearance: String(localized: "Markdown style")
        case .skills: String(localized: "Skills")
        case .mcp: String(localized: "MCP Servers")
        case .claudeMD: String(localized: "CLAUDE.md")
        }
    }

    var icon: String {
        switch self {
        case .general: "folder"
        case .calendar: "calendar.badge.clock"
        case .background: "paintpalette"
        case .appearance: "paintbrush"
        case .skills: "terminal"
        case .mcp: "server.rack"
        case .claudeMD: "doc.text"
        }
    }
}

struct SettingsView: View {
    @Binding var appTheme: AppTheme
    var calendarViewModel: GoogleCalendarViewModel?
    var onRootDirectoryChanged: (() -> Void)?
    @State private var selectedSection: SettingsSection? = .general

    var body: some View {
        HSplitView {
            settingsSidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 250)

            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var settingsSidebar: some View {
        List(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.localizedName, systemImage: section.icon)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var settingsDetail: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView(onRootDirectoryChanged: onRootDirectoryChanged)
        case .calendar:
            if let calendarViewModel {
                GoogleCalendarSettingsView(viewModel: calendarViewModel)
            }
        case .background:
            BackgroundSettingsView(appTheme: $appTheme)
        case .appearance:
            MarkdownThemeSettingsView(theme: $appTheme.markdown)
        case .skills:
            SkillsSettingsView(markdownTheme: appTheme.markdown)
        case .mcp:
            MCPServersView()
        case .claudeMD:
            ClaudeMDView(markdownTheme: appTheme.markdown)
        case .none:
            ContentUnavailableView(
                "No section selected",
                systemImage: "gearshape",
                description: Text("Select a section from the list.")
            )
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    var onRootDirectoryChanged: (() -> Void)?
    @State private var rootDirectory: URL = AppSettings.rootDirectory
    @State private var transcriptionLanguage: String = AppSettings.transcriptionLanguage
    @State private var appLanguage: String = AppSettings.appLanguage
    @State private var showRestartAlert = false
    @StateObject private var updateChecker = UpdateChecker()

    private let languages = [
        ("fr-FR", "Français"),
        ("en-US", "English"),
    ]

    var body: some View {
        Form {
            Section("Update") {
                HStack {
                    Text("Current version")
                    Spacer()
                    Text(updateChecker.currentVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Toggle("Check automatically", isOn: $updateChecker.automaticallyChecksForUpdates)

                    Spacer()

                    Button("Check now") {
                        updateChecker.checkForUpdates()
                    }
                }
            }

            Section("Data folder") {
                HStack {
                    Text("Root folder")
                    Spacer()
                    Text(rootDirectory.path)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack {
                    Spacer()
                    Button("Choose a folder...") {
                        chooseFolder()
                    }
                    Button("Reset") {
                        rootDirectory = AppSettings.defaultRootDirectory
                        AppSettings.rootDirectory = rootDirectory
                        onRootDirectoryChanged?()
                    }
                    .disabled(rootDirectory == AppSettings.defaultRootDirectory)
                }

                Text(
                    "All your Maurice files are stored here." +
                    " You can use an iCloud or Dropbox folder to sync across machines."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Transcription") {
                Picker("Language", selection: $transcriptionLanguage) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .onChange(of: transcriptionLanguage) {
                    AppSettings.transcriptionLanguage = transcriptionLanguage
                }

                Text("The language used for speech recognition. Choose the main language of your meetings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("App language") {
                Picker("Language", selection: $appLanguage) {
                    Text("System").tag("system")
                    Text("English").tag("en")
                    Text("French").tag("fr")
                }
                .onChange(of: appLanguage) {
                    AppSettings.appLanguage = appLanguage
                    showRestartAlert = true
                }
            }
        }
        .formStyle(.grouped)
        .alert("Restart required", isPresented: $showRestartAlert) {
            Button("Restart now") {
                restartApp()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("The app needs to restart to apply the language change.")
        }
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let appURL = url
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", appURL.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Select the root folder for Maurice")

        if panel.runModal() == .OK, let url = panel.url {
            rootDirectory = url
            AppSettings.rootDirectory = url
            onRootDirectoryChanged?()
        }
    }
}

private struct ClaudeMDView: View {
    var markdownTheme: MarkdownTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This file configures the AI assistant's behavior. It is read at each interaction.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            FolderFileDetailView(
                file: FolderFile(url: AppSettings.claudeMDURL),
                markdownTheme: markdownTheme
            )
        }
    }
}

// MARK: - Skills

private struct SkillsSettingsView: View {
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

// MARK: - Background

private struct TabInfo {
    let tab: AppTab
    let label: String
    let icon: String
}

private struct BackgroundSettingsView: View {
    @Binding var appTheme: AppTheme

    private let tabs: [TabInfo] = [
        TabInfo(tab: .meeting, label: String(localized: "Meetings"), icon: "calendar"),
        TabInfo(tab: .people, label: String(localized: "People"), icon: "person.2"),
        TabInfo(tab: .task, label: String(localized: "Tasks"), icon: "checklist"),
    ]

    var body: some View {
        Form {
            Section("Color per tab") {
                ForEach(tabs, id: \.tab) { item in
                    HStack {
                        Label(item.label, systemImage: item.icon)
                        Spacer()
                        ColorPicker(
                            "",
                            selection: hueBinding(for: item.tab),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                }
            }

            Section {
                HStack {
                    Text("Preview")
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                HStack(spacing: 12) {
                    ForEach(tabs, id: \.tab) { item in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(previewColor(for: item.tab))
                                .frame(height: 60)
                            Text(item.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func hueBinding(for tab: AppTab) -> Binding<Color> {
        Binding(
            get: {
                Color(hue: appTheme.hue(for: tab), saturation: 0.55, brightness: 0.50)
            },
            set: { newColor in
                let nsColor = NSColor(newColor).usingColorSpace(.sRGB) ?? NSColor(newColor)
                var h: CGFloat = 0
                nsColor.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
                appTheme.setHue(Double(h), for: tab)
            }
        )
    }

    private func previewColor(for tab: AppTab) -> Color {
        Color(hue: appTheme.hue(for: tab), saturation: 0.55, brightness: 0.20)
    }
}

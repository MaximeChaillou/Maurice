import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "Général"
    case calendar = "Google Calendar"
    case background = "Arrière-plan"
    case appearance = "Markdown style"
    case skills = "Skills"
    case mcp = "MCP Servers"
    case claudeMD = "CLAUDE.md"

    var id: String { rawValue }

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
                Label(section.rawValue, systemImage: section.icon)
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
                "Aucune section sélectionnée",
                systemImage: "gearshape",
                description: Text("Sélectionnez une section dans la liste.")
            )
        }
    }
}

// MARK: - Général

private struct GeneralSettingsView: View {
    var onRootDirectoryChanged: (() -> Void)?
    @State private var rootDirectory: URL = AppSettings.rootDirectory

    var body: some View {
        Form {
            Section("Dossier de données") {
                HStack {
                    Text("Dossier racine")
                    Spacer()
                    Text(rootDirectory.path)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack {
                    Spacer()
                    Button("Choisir un dossier…") {
                        chooseFolder()
                    }
                    Button("Réinitialiser") {
                        rootDirectory = AppSettings.defaultRootDirectory
                        AppSettings.rootDirectory = rootDirectory
                        onRootDirectoryChanged?()
                    }
                    .disabled(rootDirectory == AppSettings.defaultRootDirectory)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    pathRow("Transcripts", path: AppSettings.transcriptsDirectory.path)
                    pathRow("Mémoire", path: AppSettings.memoryDirectory.path)
                    pathRow("Thème", path: AppSettings.themeFileURL.path)
                }
            } header: {
                Text("Chemins dérivés")
            }
        }
        .formStyle(.grouped)
    }

    private func pathRow(_ label: String, path: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            Text(path)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choisir"
        panel.message = "Sélectionnez le dossier racine pour Maurice"

        if panel.runModal() == .OK, let url = panel.url {
            rootDirectory = url
            AppSettings.rootDirectory = url
            onRootDirectoryChanged?()
        }
    }
}

private struct ClaudeMDView: View {
    var markdownTheme: MarkdownTheme
    @State private var content: String = ""

    private var claudeMDURL: URL {
        AppSettings.rootDirectory.appendingPathComponent("CLAUDE.md")
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("CLAUDE.md")
                .font(.headline)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)

            Divider()

            ThemedMarkdownView(content: $content, theme: markdownTheme)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadContent() }
        .onChange(of: content) { saveContent() }
    }

    private func loadContent() {
        guard let data = try? Data(contentsOf: claudeMDURL),
              let text = String(data: data, encoding: .utf8) else {
            content = "# CLAUDE.md\n\nFichier non trouvé."
            return
        }
        content = text
    }

    private func saveContent() {
        try? content.data(using: .utf8)?.write(to: claudeMDURL, options: .atomic)
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

    var body: some View {
        HSplitView {
            skillList
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            skillDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { loadSkills() }
        .alert(
            "Supprimer le skill ?",
            isPresented: Binding(
                get: { skillToDelete != nil },
                set: { if !$0 { skillToDelete = nil } }
            )
        ) {
            Button("Annuler", role: .cancel) {
                skillToDelete = nil
            }
            Button("Supprimer", role: .destructive) {
                if let skill = skillToDelete {
                    deleteSkill(skill)
                }
            }
        } message: {
            if let skill = skillToDelete {
                Text("Le fichier « \(skill.filename) » sera supprimé définitivement.")
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
                            Label("Supprimer", systemImage: "trash")
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
                    Label("Ajouter un skill", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(12)
            }
        }
        .onChange(of: selectedSkill) {
            if let skill = selectedSkill {
                editorContent = (try? String(contentsOf: skill.url, encoding: .utf8)) ?? ""
            }
        }
    }

    // MARK: - New skill form

    private var newSkillForm: some View {
        VStack(spacing: 8) {
            TextField("Nom du skill (ex: mon-skill)", text: $newSkillName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Annuler") {
                    isAddingSkill = false
                    newSkillName = ""
                }

                Spacer()

                Button("Créer") {
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
                ThemedMarkdownView(content: $editorContent, theme: markdownTheme)
            }
            .onChange(of: editorContent) {
                if let skill = selectedSkill {
                    try? Data(editorContent.utf8).write(to: skill.url, options: .atomic)
                }
            }
        } else {
            ContentUnavailableView(
                "Aucun skill sélectionné",
                systemImage: "terminal",
                description: Text("Sélectionnez un skill pour le modifier.")
            )
        }
    }

    // MARK: - Actions

    private func loadSkills() {
        skills = MeetingSkillConfig.availableSkills()
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
        try? FileManager.default.removeItem(at: skill.url)
        if selectedSkill == skill { selectedSkill = nil }
        skillToDelete = nil
        loadSkills()
    }
}

// MARK: - Arrière-plan

private struct TabInfo {
    let tab: AppTab
    let label: String
    let icon: String
}

private struct BackgroundSettingsView: View {
    @Binding var appTheme: AppTheme

    private let tabs: [TabInfo] = [
        TabInfo(tab: .meeting, label: "Réunions", icon: "calendar"),
        TabInfo(tab: .people, label: "Personnes", icon: "person.2"),
        TabInfo(tab: .task, label: "Tâches", icon: "checklist"),
    ]

    var body: some View {
        Form {
            Section("Couleur par onglet") {
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
                    Text("Aperçu")
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

import SwiftUI

struct OnboardingView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var rootDirectory: URL = AppSettings.defaultRootDirectory
    @State private var language: String = "fr-FR"
    @State private var userName: String = ""
    @State private var userJob: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    var calendarViewModel: GoogleCalendarViewModel
    var onComplete: () -> Void

    private enum OnboardingStep {
        case welcome
        case language
        case profile
        case calendar
        case creating
    }

    var body: some View {
        ZStack {
            WaveBackground(hue: 0.58)

            VStack(spacing: 0) {
                switch step {
                case .welcome:
                    welcomeStep
                case .language:
                    languageStep
                case .profile:
                    profileStep
                case .calendar:
                    calendarStep
                case .creating:
                    creatingStep
                }
            }
            .frame(maxWidth: 560)
            .padding(40)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .padding(60)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Step 1: Welcome + Folder

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Welcome to Maurice")
                .font(.largeTitle.bold())

            Text("Choose the folder where Maurice will store your data.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            folderPicker

            Button {
                step = .language
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var folderPicker: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
            Text(rootDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Change...") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                panel.directoryURL = rootDirectory.deletingLastPathComponent()
                panel.prompt = String(localized: "Choose")
                if panel.runModal() == .OK, let url = panel.url {
                    rootDirectory = url
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Step 2: Language

    private var languageStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Transcription language")
                .font(.largeTitle.bold())

            Text("Choose the main language for speech recognition.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                languageCard(
                    title: "French",
                    locale: "fr-FR",
                    flag: "🇫🇷"
                )
                languageCard(
                    title: "English",
                    locale: "en-US",
                    flag: "🇺🇸"
                )
            }

            HStack {
                Button("Back") {
                    step = .welcome
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    step = .profile
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func languageCard(title: String, locale: String, flag: String) -> some View {
        Button {
            language = locale
        } label: {
            VStack(spacing: 8) {
                Text(flag)
                    .font(.system(size: 40))
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                language == locale ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(language == locale ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Profile

    private var profileStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Your profile")
                .font(.largeTitle.bold())

            Text("This information will be used to personalize the AI assistant.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                TextField("Name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                TextField("Job title", text: $userJob)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Back") {
                    step = .language
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    step = .calendar
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty
                    || userJob.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Step 5: Creating

    private var creatingStep: some View {
        VStack(spacing: 24) {
            if let errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)

                Text("Error")
                    .font(.largeTitle.bold())

                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    self.errorMessage = nil
                    createStructure()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if isCreating {
                ProgressView()
                    .controlSize(.large)
                Text("Creating file structure...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Maurice is ready!")
                    .font(.largeTitle.bold())

                Text(rootDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button {
                    onComplete()
                } label: {
                    Text("Get started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Create structure

    private func createStructure() {
        isCreating = true
        errorMessage = nil
        let root = rootDirectory
        let lang = language
        let name = userName.trimmingCharacters(in: .whitespaces)
        let job = userJob.trimmingCharacters(in: .whitespaces)

        Task.detached {
            do {
                try OnboardingFileSetup.buildDirectoryTree(at: root, userName: name, userJob: job)
                await MainActor.run {
                    AppSettings.rootDirectory = root
                    AppSettings.transcriptionLanguage = lang
                    AppSettings.userName = name
                    AppSettings.userJob = job
                    AppSettings.onboardingCompleted = true
                    isCreating = false
                }
            } catch {
                IssueLogger.log(.error, "Onboarding directory setup failed", context: root.path, error: error)
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Calendar step

extension OnboardingView {
    var calendarStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Connect Google Calendar")
                .font(.largeTitle.bold())

            Text("See your upcoming meetings on the home screen")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if calendarViewModel.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                        .font(.headline)
                    if let email = calendarViewModel.connectedEmail {
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else {
                Button {
                    calendarViewModel.connect()
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text(calendarViewModel.isConnecting ? "Connecting..." : "Connect Google Calendar")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(calendarViewModel.isConnecting)
            }

            if let error = calendarViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("Back") {
                    step = .profile
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if calendarViewModel.isConnected {
                    Button {
                        step = .creating
                        createStructure()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            if !calendarViewModel.isConnected {
                Button("Skip") {
                    step = .creating
                    createStructure()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.callout)
            }
        }
    }
}

// MARK: - File system helpers

enum OnboardingFileSetup {
    static func buildDirectoryTree(at root: URL, userName: String, userJob: String) throws {
        let fm = FileManager.default
        let dirs = [
            root,
            root.appendingPathComponent("Meetings"),
            root.appendingPathComponent("People"),
            root.appendingPathComponent("Memory"),
            root.appendingPathComponent("Memory/People"),
            root.appendingPathComponent(".maurice"),
            root.appendingPathComponent(".claude/commands"),
        ]
        for dir in dirs {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        copyTemplateIfMissing(
            "CLAUDE",
            to: root.appendingPathComponent("CLAUDE.md"),
            replacements: ["{{name}}": userName, "{{job}}": userJob]
        )
        copyMissingTemplates(to: root)
        try writeIfMissing("[]", to: root.appendingPathComponent(".maurice/search_index.json"))

        let tasksURL = root.appendingPathComponent("Tasks.md")
        if !fm.fileExists(atPath: tasksURL.path) {
            fm.createFile(atPath: tasksURL.path, contents: nil)
        }

        let themeURL = root.appendingPathComponent(".maurice/theme.json")
        if !fm.fileExists(atPath: themeURL.path) {
            let data = try JSONEncoder().encode(AppTheme())
            try data.write(to: themeURL, options: .atomic)
        }
    }

    static func writeIfMissing(_ content: String, to url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Copy any missing skill templates to an existing installation.
    static func copyMissingTemplates(to root: URL) {
        let commands = root.appendingPathComponent(".claude/commands")
        try? FileManager.default.createDirectory(at: commands, withIntermediateDirectories: true)

        let templates: [(resource: String, filename: String)] = [
            ("maurice-convert-file-to-md", "maurice-convert-file-to-md.md"),
            ("prepare-meeting", "prepare-meeting.md"),
            ("summarize-meeting", "summarize-meeting.md"),
        ]
        for template in templates {
            copyTemplateIfMissing(template.resource, to: commands.appendingPathComponent(template.filename))
        }
    }

    static func copyTemplateIfMissing(
        _ name: String, to url: URL, replacements: [String: String] = [:]
    ) {
        guard !FileManager.default.fileExists(atPath: url.path),
              let sourceURL = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Templates")
        else { return }
        do {
            if replacements.isEmpty {
                try FileManager.default.copyItem(at: sourceURL, to: url)
            } else {
                var content = try String(contentsOf: sourceURL, encoding: .utf8)
                for (placeholder, value) in replacements {
                    content = content.replacingOccurrences(of: placeholder, with: value)
                }
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            IssueLogger.log(.error, "Failed to copy template", context: "\(name).md → \(url.path)", error: error)
        }
    }
}

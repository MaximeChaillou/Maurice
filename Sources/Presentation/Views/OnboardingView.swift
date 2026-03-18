import SwiftUI

struct OnboardingView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var rootDirectory: URL = AppSettings.defaultRootDirectory
    @State private var language: String = "fr-FR"
    @State private var isCreating = false
    @State private var errorMessage: String?
    var onComplete: () -> Void

    private enum OnboardingStep {
        case welcome
        case language
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

            Text("Bienvenue sur Maurice")
                .font(.largeTitle.bold())

            Text("Choisissez le dossier où Maurice stockera vos données.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            folderPicker

            Button {
                step = .language
            } label: {
                Text("Continuer")
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
            Button("Modifier…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                panel.directoryURL = rootDirectory.deletingLastPathComponent()
                panel.prompt = "Choisir"
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

            Text("Langue de transcription")
                .font(.largeTitle.bold())

            Text("Choisissez la langue principale pour la reconnaissance vocale.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                languageCard(
                    title: "Français",
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
                Button("Retour") {
                    step = .welcome
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    step = .creating
                    createStructure()
                } label: {
                    Text("Terminer")
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

    // MARK: - Step 3: Creating

    private var creatingStep: some View {
        VStack(spacing: 24) {
            if let errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)

                Text("Erreur")
                    .font(.largeTitle.bold())

                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Réessayer") {
                    self.errorMessage = nil
                    createStructure()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if isCreating {
                ProgressView()
                    .controlSize(.large)
                Text("Création de l'arborescence…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Maurice est prêt !")
                    .font(.largeTitle.bold())

                Text(rootDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button {
                    onComplete()
                } label: {
                    Text("Commencer")
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

        Task.detached {
            do {
                try Self.buildDirectoryTree(at: root)
                await MainActor.run {
                    AppSettings.rootDirectory = root
                    AppSettings.transcriptionLanguage = lang
                    AppSettings.onboardingCompleted = true
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }

    // MARK: - File system helpers (nonisolated)

    nonisolated private static func buildDirectoryTree(at root: URL) throws {
        let fm = FileManager.default
        let dirs = [
            root,
            root.appendingPathComponent("Meetings"),
            root.appendingPathComponent("People"),
            root.appendingPathComponent("Memory"),
            root.appendingPathComponent(".maurice"),
            root.appendingPathComponent(".claude/commands"),
        ]
        for dir in dirs {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        copyTemplateIfMissing("CLAUDE", to: root.appendingPathComponent("CLAUDE.md"))
        copyTemplateIfMissing("maurice-convert-file-to-md", to: root.appendingPathComponent(".claude/commands/maurice-convert-file-to-md.md"))
        copyTemplateIfMissing("resume-meeting", to: root.appendingPathComponent(".claude/commands/resume-meeting.md"))
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

    nonisolated private static func writeIfMissing(_ content: String, to url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated private static func copyTemplateIfMissing(_ name: String, to url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path),
              let sourceURL = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Templates")
        else { return }
        try? FileManager.default.copyItem(at: sourceURL, to: url)
    }
}

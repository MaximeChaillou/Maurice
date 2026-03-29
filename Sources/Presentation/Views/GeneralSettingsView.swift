import SwiftUI

struct GeneralSettingsView: View {
    var onRootDirectoryChanged: (() -> Void)?
    @State private var rootDirectory: URL = AppSettings.rootDirectory
    @State private var transcriptionLanguage: String = AppSettings.transcriptionLanguage
    @State private var appLanguage: String = AppSettings.appLanguage
    @AppStorage(AppSettings.appearanceModeKey) private var appearanceMode = "system"
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

            Section("Appearance") {
                Picker("Mode", selection: $appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
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
        do { try task.run() } catch {
            IssueLogger.log(.error, "Failed to relaunch app", error: error)
        }
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

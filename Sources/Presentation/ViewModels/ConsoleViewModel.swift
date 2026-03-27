import AppKit
import SwiftTerm

private func findClaudeExecutable() -> String? {
    let candidates = [
        "\(NSHomeDirectory())/.local/bin/claude",
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude"
    ]
    for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
        return path
    }
    let whichProc = Process()
    let whichPipe = Pipe()
    whichProc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    whichProc.arguments = ["claude"]
    whichProc.standardOutput = whichPipe
    whichProc.standardError = FileHandle.nullDevice
    try? whichProc.run()
    whichProc.waitUntilExit()
    let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
    if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !path.isEmpty {
        return path
    }
    return nil
}

@Observable
@MainActor
final class ConsoleViewModel {
    private(set) var isRunning = false
    private(set) var errorMessage: String?
    var shouldExpand = false
    private var terminalView: LocalProcessTerminalView?
    private var sessionStarted = false

    private var claudePath: String?

    init() {
        claudePath = findClaudeExecutable()
    }

    func getOrCreateTerminalView(
        delegate: LocalProcessTerminalViewDelegate
    ) -> LocalProcessTerminalView {
        if let existing = terminalView {
            return existing
        }
        let tv = LocalProcessTerminalView(frame: .zero)
        let fontSize: CGFloat = 13
        tv.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        let bgColor = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.85)
        let fgColor = NSColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1)
        tv.nativeBackgroundColor = bgColor
        tv.nativeForegroundColor = fgColor
        tv.layer?.backgroundColor = bgColor.cgColor
        tv.caretColor = .systemCyan
        tv.getTerminal().setCursorStyle(.steadyBar)
        tv.processDelegate = delegate
        terminalView = tv

        if !sessionStarted {
            Task { @MainActor in
                self.startSession()
            }
        }

        return tv
    }

    func startSession() {
        guard let terminalView else { return }
        guard !isRunning else { return }
        sessionStarted = true

        guard let path = claudePath else {
            errorMessage = "Impossible de trouver 'claude'. Installez Claude Code."
            return
        }

        errorMessage = nil
        isRunning = true

        let env = buildEnvironment()
        let workingDir = AppSettings.rootDirectory.path

        terminalView.startProcess(
            executable: path,
            args: ["--permission-mode", "acceptEdits"],
            environment: env,
            execName: "claude",
            currentDirectory: workingDir
        )
    }

    func sendCommand(_ command: String) {
        guard isRunning, let terminalView else { return }
        let data = Array((command + "\r").utf8)
        terminalView.send(data)
    }

    func sendSkill(filename: String, parameter: String? = nil) {
        shouldExpand = true
        let commandName = filename.replacingOccurrences(of: ".md", with: "")
        if let param = parameter, !param.isEmpty {
            sendCommand("/\(commandName) \(param)")
        } else {
            sendCommand("/\(commandName)")
        }
    }

    func sendImportSkill(source: String, targetPath: String) {
        shouldExpand = true
        sendCommand(
            "/maurice-convert-file-to-md source: \(source)\ntarget: \(targetPath)"
        )
    }

    func stop() {
        guard isRunning, let terminalView else { return }
        // Send Ctrl+C
        terminalView.send([3])
    }

    func restart() {
        if isRunning, let terminalView {
            let data = Array("exit\n".utf8)
            terminalView.send(data)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            self.isRunning = false
            self.terminalView?.getTerminal().resetToInitialState()
            self.startSession()
        }
    }

    func processTerminated() {
        isRunning = false
    }

    private func buildEnvironment() -> [String] {
        var envDict = ProcessInfo.processInfo.environment
        // Remove CLAUDECODE to avoid non-interactive mode
        envDict.removeValue(forKey: "CLAUDECODE")
        // Ensure terminal color support is detected by CLI tools
        envDict["TERM"] = "xterm-256color"
        envDict["COLORTERM"] = "truecolor"
        envDict["FORCE_COLOR"] = "1"
        return envDict.map { "\($0.key)=\($0.value)" }
    }
}

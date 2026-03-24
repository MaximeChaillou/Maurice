import Foundation

extension Notification.Name {
    static let skillRunnerDidFinish = Notification.Name("skillRunnerDidFinish")
    static let fileSystemDidChange = Notification.Name("fileSystemDidChange")
}

enum SkillOutputKind {
    case assistant
    case tool
    case system
    case error
}

struct SkillOutputLine: Identifiable {
    let id = UUID()
    let text: String
    let kind: SkillOutputKind
}

@Observable
@MainActor
final class SkillRunner {
    var outputLines: [SkillOutputLine] = []
    private(set) var isRunning = false
    private(set) var lastAssistantLine: String = ""
    var currentText: String = ""

    private var process: Process?
    private var outPipe: Pipe?
    private var currentToolName: String?
    private var currentToolInput: String = ""

    var actionID: UUID?
    private(set) var skillLabel: String?

    static var mauricePermissions: [String] {
        let root = AppSettings.rootDirectory.path
        return [
            "--allowedTools", "Read(\(root)/**)",
            "--allowedTools", "Write(\(root)/**)",
            "--allowedTools", "Edit(\(root)/**)",
            "--allowedTools", "Glob(\(root)/**)",
            "--allowedTools", "Grep(\(root)/**)",
            "--allowedTools", "Bash(ls:*,mkdir:*,cat:*,mv:*,cp:*,rm:*)",
            "--allowedTools", "mcp__*"
        ]
    }

    func run(skillFilename: String, buttonName: String, parameter: String? = nil, workingDirectory: URL) {
        skillLabel = buttonName
        let commandName = skillFilename.replacingOccurrences(of: ".md", with: "")
        let prompt: String
        if let param = parameter, !param.isEmpty {
            prompt = "/\(commandName) \(param)"
        } else {
            prompt = "/\(commandName)"
        }
        launchClaude(
            prompt: prompt,
            extraArgs: ["--permission-mode", "bypassPermissions"] + Self.mauricePermissions,
            workingDirectory: workingDirectory
        )
    }

    func runPrompt(_ prompt: String, workingDirectory: URL) {
        skillLabel = nil
        launchClaude(
            prompt: prompt,
            extraArgs: ["--permission-mode", "bypassPermissions"] + Self.mauricePermissions,
            workingDirectory: workingDirectory
        )
    }

    func runImport(source: String, targetPath: String, workingDirectory: URL) {
        skillLabel = "Import"
        let prompt = "/maurice-convert-file-to-md source: \(source)\ntarget: \(targetPath)"
        let sourceDir = URL(fileURLWithPath: source).deletingLastPathComponent().path
        let targetDir = URL(fileURLWithPath: targetPath).deletingLastPathComponent().path
        launchClaude(
            prompt: prompt,
            extraArgs: [
                "--permission-mode", "bypassPermissions",
                "--allowedTools", "Read(\(sourceDir)/**)",
                "--allowedTools", "Write(\(targetDir)/**)"
            ],
            workingDirectory: workingDirectory
        )
    }

    private static func findClaudeExecutable() -> URL? {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        // Fallback: use `which` to find claude in PATH
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
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func launchClaude(prompt: String, extraArgs: [String], workingDirectory: URL) {
        guard !isRunning else { return }

        isRunning = true
        outputLines = []
        lastAssistantLine = ""
        currentText = ""
        appendLine("[command] \(prompt)", kind: .system)

        guard let claudeURL = Self.findClaudeExecutable() else {
            appendLine(
                "Erreur : impossible de trouver 'claude'. Installez Claude Code et vérifiez qu'il est dans votre PATH.",
                kind: .error
            )
            isRunning = false
            return
        }

        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = claudeURL
        proc.arguments = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages"
        ] + extraArgs
        proc.currentDirectoryURL = workingDirectory
        let errPipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = errPipe

        var environment = ProcessInfo.processInfo.environment
        environment["CLAUDECODE"] = ""
        proc.environment = environment

        self.process = proc
        self.outPipe = pipe

        let readQueue = DispatchQueue(label: "skill-runner-read")
        readQueue.async { [weak self] in
            self?.readStreamJSON(from: pipe)
        }

        let errQueue = DispatchQueue(label: "skill-runner-err")
        errQueue.async { [weak self] in
            self?.readStderr(from: errPipe)
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
                NotificationCenter.default.post(name: .skillRunnerDidFinish, object: nil)
            }
        }

        do {
            try proc.run()
        } catch {
            isRunning = false
            appendLine("Error: \(error.localizedDescription)", kind: .system)
        }
    }

    func stop() {
        process?.terminate()
    }

    // MARK: - Stream JSON parsing

    nonisolated private func readStreamJSON(from pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        var buffer = Data()

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)

            // Process complete JSON lines
            while let newlineRange = buffer.range(of: Data([0x0A])) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
                processJSONLine(lineData)
            }
        }

        // Process remaining
        if !buffer.isEmpty {
            processJSONLine(buffer)
        }
    }

    nonisolated private func processJSONLine(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        Task { @MainActor [weak self] in
            self?.handleEvent(type: type, json: json)
        }
    }

    private func handleEvent(type: String, json: [String: Any]) {
        switch type {
        case "stream_event":
            handleStreamEvent(json)
        case "system":
            if let message = json["message"] as? String {
                appendLine("[system] \(message)", kind: .system)
            }
        case "result":
            // Content already displayed via stream_events, skip to avoid duplication
            break
        default:
            break
        }
    }

    private func handleStreamEvent(_ json: [String: Any]) {
        guard let event = json["event"] as? [String: Any] else { return }
        let eventType = event["type"] as? String ?? ""

        // Text delta — partial message streaming
        if let delta = event["delta"] as? [String: Any],
           let deltaType = delta["type"] as? String {
            if deltaType == "text_delta", let text = delta["text"] as? String {
                currentText += text
                lastAssistantLine = currentLineFromBuffer()
                return
            }
            if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                currentToolInput += partial
                return
            }
        }

        // Message stop — flush current text as lines
        if eventType == "message_stop" {
            flushCurrentText()
            return
        }

        // Tool use start
        if eventType == "content_block_start",
           let contentBlock = event["content_block"] as? [String: Any],
           let blockType = contentBlock["type"] as? String,
           blockType == "tool_use",
           let name = contentBlock["name"] as? String {
            flushCurrentText()
            currentToolName = name
            currentToolInput = ""
            return
        }

        // Tool use end — display tool name + key params
        if eventType == "content_block_stop", let name = currentToolName {
            appendLine(formatToolCall(name: name, inputJSON: currentToolInput), kind: .tool)
            currentToolName = nil
            currentToolInput = ""
            return
        }

        // Tool result
        if eventType == "content_block_start",
           let contentBlock = event["content_block"] as? [String: Any],
           let blockType = contentBlock["type"] as? String,
           blockType == "tool_result",
           let content = contentBlock["content"] as? String,
           !content.isEmpty {
            let preview = String(content.prefix(200))
            appendLine("  → \(preview)", kind: .tool)
        }
    }

    func formatToolCall(name: String, inputJSON: String) -> String {
        guard let data = inputJSON.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return "[tool] \(name)" }

        let details = toolSummary(name: name, params: params)
        if details.isEmpty { return "[tool] \(name)" }
        return "[tool] \(name) — \(details)"
    }

    func toolSummary(name: String, params: [String: Any]) -> String {
        let filePathTools: Set<String> = ["Read", "Edit", "Write"]
        if filePathTools.contains(name), let path = params["file_path"] as? String {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        if name == "Bash", let cmd = params["command"] as? String {
            return String(cmd.prefix(80))
        }
        if name == "Grep" || name == "Glob", let pattern = params["pattern"] as? String {
            return name == "Grep" ? "\"\(pattern)\"" : pattern
        }
        let keys = params.compactMap { key, val -> String? in
            if let str = val as? String { return "\(key): \(String(str.prefix(50)))" }
            return nil
        }
        if !keys.isEmpty { return keys.prefix(3).joined(separator: ", ") }
        return ""
    }

    // MARK: - Stderr

    nonisolated private func readStderr(from pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        var buffer = Data()

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)

            while let newlineRange = buffer.range(of: Data([0x0A])) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
                if let line = String(data: lineData, encoding: .utf8),
                   !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Task { @MainActor [weak self] in
                        self?.appendLine(line, kind: .error)
                    }
                }
            }
        }

        if !buffer.isEmpty,
           let line = String(data: buffer, encoding: .utf8),
           !line.trimmingCharacters(in: .whitespaces).isEmpty {
            Task { @MainActor [weak self] in
                self?.appendLine(line, kind: .error)
            }
        }
    }

    // MARK: - Helpers

    private func currentLineFromBuffer() -> String {
        let lines = currentText.components(separatedBy: .newlines)
        return lines.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
    }

    private func flushCurrentText() {
        guard !currentText.isEmpty else { return }
        let lines = currentText.components(separatedBy: .newlines)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            outputLines.append(SkillOutputLine(text: line, kind: .assistant))
        }
        if let last = outputLines.last(where: { $0.kind == .assistant }) {
            lastAssistantLine = last.text
        }
        currentText = ""
    }

    private func appendLine(_ line: String, kind: SkillOutputKind) {
        outputLines.append(SkillOutputLine(text: line, kind: kind))
        if kind == .assistant {
            lastAssistantLine = line
        }
    }
}

import Foundation

extension Notification.Name {
    static let skillRunnerDidFinish = Notification.Name("skillRunnerDidFinish")
}

enum SkillOutputKind {
    case assistant
    case tool
    case system
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

    func run(skillFilename: String, workingDirectory: URL) {
        let commandName = skillFilename.replacingOccurrences(of: ".md", with: "")
        launchClaude(
            prompt: "/\(commandName)",
            extraArgs: ["--permission-mode", "acceptEdits"],
            workingDirectory: workingDirectory
        )
    }

    func runPrompt(_ prompt: String, workingDirectory: URL) {
        launchClaude(prompt: prompt, extraArgs: [], workingDirectory: workingDirectory)
    }

    private func launchClaude(prompt: String, extraArgs: [String], workingDirectory: URL) {
        guard !isRunning else { return }

        isRunning = true
        outputLines = []
        lastAssistantLine = ""
        currentText = ""

        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: "/Users/maxime/.local/bin/claude")
        proc.arguments = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages"
        ] + extraArgs
        proc.currentDirectoryURL = workingDirectory
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        environment["CLAUDECODE"] = ""
        proc.environment = environment

        self.process = proc
        self.outPipe = pipe

        let readQueue = DispatchQueue(label: "skill-runner-read")
        readQueue.async { [weak self] in
            self?.readStreamJSON(from: pipe)
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
            appendLine("Erreur: \(error.localizedDescription)", kind: .system)
        }
    }

    func send(_ text: String) {
        // stream-json + -p is non-interactive, input not supported
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
                appendLine("[système] \(message)", kind: .system)
            }
        case "result":
            // Le contenu est déjà affiché via les stream_events, ignorer pour éviter la duplication
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

    private func formatToolCall(name: String, inputJSON: String) -> String {
        guard let data = inputJSON.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return "[outil] \(name)" }

        let details = toolSummary(name: name, params: params)
        if details.isEmpty { return "[outil] \(name)" }
        return "[outil] \(name) — \(details)"
    }

    private func toolSummary(name: String, params: [String: Any]) -> String {
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

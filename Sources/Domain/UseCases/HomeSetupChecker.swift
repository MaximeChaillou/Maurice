import Foundation
import Observation

@Observable
@MainActor
final class HomeSetupChecker {
    enum ConsoleState: Equatable {
        case checking
        case ok(version: String)
        case failed(reason: String)
    }

    struct MemoryStatus: Equatable {
        let presentCount: Int
        let totalCount: Int
        var isComplete: Bool { presentCount == totalCount && totalCount > 0 }
    }

    static let requiredMemoryFiles = ["Company.md", "Directory.md", "Lexicon.md"]

    private(set) var memoryStatus: MemoryStatus = .init(presentCount: 0, totalCount: requiredMemoryFiles.count)
    private(set) var consoleState: ConsoleState = .checking

    func refresh() {
        refreshMemory()
        Task { await refreshConsole() }
    }

    func refreshMemory() {
        let dir = AppSettings.memoryDirectory
        let fm = FileManager.default
        let present = Self.requiredMemoryFiles.filter {
            fm.fileExists(atPath: dir.appendingPathComponent($0).path)
        }
        memoryStatus = MemoryStatus(
            presentCount: present.count,
            totalCount: Self.requiredMemoryFiles.count
        )
    }

    func refreshConsole() async {
        consoleState = .checking
        consoleState = await runClaudeVersion()
    }

    private func runClaudeVersion() async -> ConsoleState {
        guard let path = ClaudeBinaryLocator.find() else {
            return .failed(reason: String(localized: "Claude CLI not found"))
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<ConsoleState, Never>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["--version"]
            let outPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { proc in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: .ok(version: output))
                } else {
                    let reason = output.isEmpty
                        ? "Exit code \(Int(proc.terminationStatus))"
                        : output
                    continuation.resume(returning: .failed(reason: reason))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failed(reason: error.localizedDescription))
            }
        }
    }
}

import Foundation

enum ClaudeBinaryLocator {
    static func find() -> String? {
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
        do {
            try whichProc.run()
        } catch {
            IssueLogger.log(.warning, "Failed to locate claude binary via which", error: error)
            return nil
        }
        whichProc.waitUntilExit()
        let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }
        return nil
    }
}

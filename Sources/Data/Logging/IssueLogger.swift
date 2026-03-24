import Foundation

enum IssueLevel: String {
    case error = "ERROR"
    case warning = "WARNING"
    case crash = "CRASH"
}

enum IssueLogger {
    private static let fileName = "issues.log"
    private static let maxFileSize: UInt64 = 2 * 1024 * 1024 // 2 MB

    private static var logFileURL: URL {
        AppSettings.rootDirectory
            .appendingPathComponent(".maurice", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func log(
        _ level: IssueLevel,
        _ message: String,
        context: String? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let source = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
        var entry = "[\(timestamp)] [\(level.rawValue)] [\(source)] \(message)"
        if let ctx = context {
            entry += " | context: \(ctx)"
        }
        if let err = error {
            entry += " | error: \(err.localizedDescription)"
        }
        entry += "\n"

        Task.detached(priority: .utility) {
            append(entry)
        }
    }

    static func logCrash(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [CRASH] \(message)\n"
        appendSync(entry)
    }

    // MARK: - File operations

    private static func append(_ entry: String) {
        let url = logFileURL
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        guard let data = entry.data(using: .utf8) else { return }

        if fm.fileExists(atPath: url.path) {
            rotateIfNeeded(url: url)
        }

        if fm.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            fm.createFile(atPath: url.path, contents: data)
        }
    }

    private static func appendSync(_ entry: String) {
        let url = logFileURL
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        guard let data = entry.data(using: .utf8) else { return }

        if fm.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            fm.createFile(atPath: url.path, contents: data)
        }
    }

    private static func rotateIfNeeded(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64,
              size > maxFileSize
        else { return }

        let backupURL = url.deletingLastPathComponent().appendingPathComponent("issues.old.log")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: url, to: backupURL)
    }

    // MARK: - Crash handling

    static func installCrashHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.prefix(20).joined(separator: "\n  ")
            IssueLogger.logCrash(
                "\(exception.name.rawValue): \(exception.reason ?? "unknown")\n  \(stack)"
            )
        }

        let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGTRAP]
        for sig in signals {
            signal(sig) { sigNum in
                IssueLogger.logCrash("Signal \(sigNum) received")
                exit(sigNum)
            }
        }
    }
}

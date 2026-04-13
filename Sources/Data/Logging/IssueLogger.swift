import Foundation

extension Error {
    /// True if the error is a "file not found" (ENOENT / NSFileReadNoSuchFileError).
    /// Useful to silence warnings for absent-but-expected files (first run, optional configs).
    var isFileNotFound: Bool {
        let nsError = self as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError
    }
}

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
            let desc = err.localizedDescription
            let detail = String(describing: err)
            if detail != desc {
                entry += " | error: \(desc) (\(detail))"
            } else {
                entry += " | error: \(desc)"
            }
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

    /// Fallback used when the logger itself can't write to disk. Writes to stderr so the
    /// failure is at least visible in Xcode/console, otherwise the issue is invisible.
    private static func reportSelfFailure(_ message: String, error: Error) {
        let line = "[Maurice][IssueLogger] \(message): \(error.localizedDescription)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private static func ensureLogDirectory(_ dir: URL, fm: FileManager) -> Bool {
        guard !fm.fileExists(atPath: dir.path) else { return true }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return true
        } catch {
            reportSelfFailure("Failed to create log directory at \(dir.path)", error: error)
            return false
        }
    }

    private static func writeData(_ data: Data, to url: URL, fm: FileManager) {
        if fm.fileExists(atPath: url.path) {
            do {
                let handle = try FileHandle(forWritingTo: url)
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } catch {
                reportSelfFailure("Failed to open log file for writing at \(url.path)", error: error)
            }
        } else {
            fm.createFile(atPath: url.path, contents: data)
        }
    }

    private static func append(_ entry: String) {
        let url = logFileURL
        let fm = FileManager.default
        guard ensureLogDirectory(url.deletingLastPathComponent(), fm: fm),
              let data = entry.data(using: .utf8) else { return }

        if fm.fileExists(atPath: url.path) {
            rotateIfNeeded(url: url)
        }
        writeData(data, to: url, fm: fm)
    }

    private static func appendSync(_ entry: String) {
        let url = logFileURL
        let fm = FileManager.default
        guard ensureLogDirectory(url.deletingLastPathComponent(), fm: fm),
              let data = entry.data(using: .utf8) else { return }
        writeData(data, to: url, fm: fm)
    }

    private static func rotateIfNeeded(url: URL) {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64,
              size > maxFileSize
        else { return }

        let backupURL = url.deletingLastPathComponent().appendingPathComponent("issues.old.log")
        // Remove stale backup (absent on first rotation — silent is correct there).
        do {
            try fm.removeItem(at: backupURL)
        } catch {
            if !error.isFileNotFound {
                reportSelfFailure("Failed to remove old log backup at \(backupURL.path)", error: error)
            }
        }
        do {
            try fm.moveItem(at: url, to: backupURL)
        } catch {
            reportSelfFailure("Failed to rotate log file \(url.path) → \(backupURL.path)", error: error)
        }
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

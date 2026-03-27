import Foundation
import os

private let logger = Logger(subsystem: "com.maxime.maurice", category: "Storage")

final class FileTranscriptionStorage: TranscriptionStorage, Sendable {
    static let headerPrefix = "Maurice Transcript"
    static let headerSeparator = " — "

    static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let mm = String(format: "%02d", Int(seconds) / 60)
        let ss = String(format: "%02d", Int(seconds) % 60)
        return "[\(mm):\(ss)]"
    }

    static func header(for date: Date) -> String {
        "\(headerPrefix)\(headerSeparator)\(DateFormatters.dayAndTime.string(from: date))"
    }

    func beginLiveSession(startDate: Date, subdirectory: String? = nil) throws -> URL {
        let fileName = "\(DateFormatters.dayOnly.string(from: startDate)).transcript"

        let base: URL
        if let sub = subdirectory {
            base = sub.hasPrefix("People/") ? AppSettings.rootDirectory : AppSettings.meetingsDirectory
        } else {
            base = AppSettings.meetingsDirectory
        }
        let targetDir = subdirectory.map { base.appendingPathComponent($0, isDirectory: true) } ?? base
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let url = targetDir.appendingPathComponent(fileName)

        let header = Self.header(for: startDate) + "\n\n"

        // Create a note file if none exists for this date in a meeting folder
        if subdirectory != nil {
            let noteFileName = "\(DateFormatters.dayOnly.string(from: startDate)).md"
            let noteURL = targetDir.appendingPathComponent(noteFileName)
            if !FileManager.default.fileExists(atPath: noteURL.path) {
                FileManager.default.createFile(atPath: noteURL.path, contents: nil)
            }
        }

        if FileManager.default.fileExists(atPath: url.path) {
            // Append to existing transcript with separator
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            let separator = "\n---\n\n\(header)"
            if let data = separator.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } else {
            try header.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    func appendEntry(_ entry: TranscriptionEntry, to fileURL: URL) throws {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        handle.seekToEndOfFile()

        let line = "\(Self.formatTimestamp(entry.timestamp))\n\(entry.text)\n\n"

        guard let data = line.data(using: .utf8) else {
            IssueLogger.log(.error, "Failed to encode transcript entry to UTF-8", context: fileURL.path)
            return
        }
        try handle.write(contentsOf: data)
    }

    func listDirectory(_ url: URL) -> TranscriptDirectoryContents {
        let contents = DirectoryScanner.scan(at: url, fileExtension: "txt")

        var transcripts = contents.files.compactMap { parseTranscript(at: $0.url) }
        transcripts.sort { $0.date > $1.date }

        return TranscriptDirectoryContents(folders: contents.folders, transcripts: transcripts)
    }

    func delete(_ transcript: StoredTranscript) async throws {
        try FileManager.default.removeItem(at: transcript.url)
    }

    func rename(_ transcript: StoredTranscript, to newName: String) async throws -> StoredTranscript {
        let invalidChars = CharacterSet(charactersIn: "/:\\*?\"<>|")
        let sanitized = newName
            .components(separatedBy: invalidChars).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            throw StorageError.invalidName
        }
        let parentDir = transcript.url.deletingLastPathComponent()
        let newURL = parentDir.appendingPathComponent("\(sanitized).txt")
        if FileManager.default.fileExists(atPath: newURL.path) {
            throw StorageError.duplicateName(sanitized)
        }
        try FileManager.default.moveItem(at: transcript.url, to: newURL)
        return StoredTranscript(id: newURL, name: sanitized, date: transcript.date, entries: transcript.entries)
    }

    func parseTranscriptFile(at url: URL) -> StoredTranscript? {
        parseTranscript(at: url)
    }

    private func parseTranscript(at url: URL) -> StoredTranscript? {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            if FileManager.default.fileExists(atPath: url.path) {
                logger.warning("Impossible de lire \(url.lastPathComponent): \(error.localizedDescription)")
                IssueLogger.log(.warning, "Failed to read transcript", context: url.path, error: error)
            }
            return nil
        }

        let lines = content.components(separatedBy: "\n")
        guard let header = lines.first, header.hasPrefix(Self.headerPrefix) else { return nil }

        let date = parseDateFromHeader(header) ?? Date.distantPast

        var currentTimestamp: String?
        var entries: [TranscriptLine] = []

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("["), let closeBracket = trimmed.firstIndex(of: "]") {
                let inside = trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket]
                let parts = inside.split(separator: ":")
                if parts.count == 2,
                   let minutes = Int(parts[0]),
                   let seconds = Int(parts[1]) {
                    let entryDate = date.addingTimeInterval(Double(minutes * 60 + seconds))
                    currentTimestamp = DateFormatters.timeOnly.string(from: entryDate)
                }
                continue
            }
            if trimmed.hasPrefix(Self.headerPrefix) || trimmed == "---" {
                entries.append(.separator(trimmed))
                continue
            }
            entries.append(.text(trimmed, timestamp: currentTimestamp))
        }

        var name = url.deletingPathExtension().lastPathComponent
        if name.hasPrefix("transcription_") {
            name = name.replacingOccurrences(of: "transcription_", with: "")
                .replacingOccurrences(of: "_", with: " ")
        }

        return StoredTranscript(id: url, name: name, date: date, entries: entries)
    }

    private func parseDateFromHeader(_ header: String) -> Date? {
        guard let dashRange = header.range(of: Self.headerSeparator) else { return nil }
        let dateString = String(header[dashRange.upperBound...])
        return DateFormatters.dayAndTime.date(from: dateString)
    }
}

enum StorageError: Error, LocalizedError {
    case invalidName
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .invalidName: "Le nom du fichier est invalide."
        case .duplicateName(let name): "Un fichier nommé « \(name) » existe déjà."
        }
    }
}

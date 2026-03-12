import Foundation

final class FileTranscriptionStorage: TranscriptionStorage, Sendable {
    private var directory: URL {
        let dir = AppSettings.transcriptsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func save(_ transcription: Transcription) async throws {
        let text = formatTranscript(transcription)
        let fileName = formatFileName(for: transcription)
        let url = directory.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func beginLiveSession(startDate: Date, subdirectory: String? = nil) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "transcription_\(formatter.string(from: startDate)).txt"

        let targetDir: URL
        if let sub = subdirectory {
            targetDir = directory.appendingPathComponent(sub, isDirectory: true)
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } else {
            targetDir = directory
        }
        let url = targetDir.appendingPathComponent(fileName)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let header = "Maurice Transcript — \(dateFormatter.string(from: startDate))\n\n"
        try header.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func appendEntry(_ entry: TranscriptionEntry, to fileURL: URL) throws {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        handle.seekToEndOfFile()

        let currentMinute = Int(entry.timestamp) / 60
        let mm = String(format: "%02d", currentMinute)
        let ss = String(format: "%02d", Int(entry.timestamp) % 60)
        let line = "[\(mm):\(ss)]\n\(entry.text)\n\n"

        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }

    private func formatTranscript(_ transcription: Transcription) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = []
        lines.append("Maurice Transcript — \(dateFormatter.string(from: transcription.startDate))")
        lines.append("")

        var lastMinute = -1

        for entry in transcription.entries {
            let currentMinute = Int(entry.timestamp) / 60

            if currentMinute != lastMinute {
                if lastMinute >= 0 { lines.append("") }
                let mm = String(format: "%02d", currentMinute)
                let ss = String(format: "%02d", Int(entry.timestamp) % 60)
                lines.append("[\(mm):\(ss)]")
                lastMinute = currentMinute
            }

            lines.append(entry.text)
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    func list() async throws -> [StoredTranscript] {
        listDirectory(directory).transcripts
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
        let sanitized = newName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let newURL = directory.appendingPathComponent("\(sanitized).txt")
        try FileManager.default.moveItem(at: transcript.url, to: newURL)
        return StoredTranscript(id: newURL, name: sanitized, date: transcript.date, entries: transcript.entries)
    }

    private func parseTranscript(at url: URL) -> StoredTranscript? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: "\n")
        guard let header = lines.first, header.hasPrefix("Maurice Transcript") else { return nil }

        let date = parseDateFromHeader(header) ?? Date.distantPast

        let entries = lines.dropFirst()
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty && !trimmed.hasPrefix("[")
            }

        let name = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "transcription_", with: "")
            .replacingOccurrences(of: "_", with: " ")

        return StoredTranscript(id: url, name: name, date: date, entries: entries)
    }

    private func parseDateFromHeader(_ header: String) -> Date? {
        guard let dashRange = header.range(of: " — ") else { return nil }
        let dateString = String(header[dashRange.upperBound...])
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: dateString)
    }

    private func formatFileName(for transcription: Transcription) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: transcription.startDate)
        return "transcription_\(dateString).txt"
    }
}

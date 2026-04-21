import Foundation

struct FolderItem: Identifiable {
    let name: String, url: URL, files: [FolderFile]
    var dateEntries: [MeetingDateEntry] = []
    var icon: String?
    var relativePath: String = ""
    var id: String { relativePath.isEmpty ? name : relativePath }
    var fileCount: Int { max(files.count, dateEntries.count) }
}

struct PeopleCategory: Identifiable {
    let name: String
    var people: [FolderItem]
    var id: String { name }
}

enum EntryDeleteAction {
    case note(MeetingDateEntry)
    case transcript(MeetingDateEntry)
    case both(MeetingDateEntry)

    var entry: MeetingDateEntry {
        switch self {
        case .note(let e), .transcript(let e), .both(let e): e
        }
    }

    var message: String {
        switch self {
        case .note: "La note du \(entry.dateString) sera supprimée définitivement."
        case .transcript: "Le transcript du \(entry.dateString) sera supprimé définitivement."
        case .both: "La note et le transcript du \(entry.dateString) seront supprimés définitivement."
        }
    }
}

struct MeetingDateEntry: Identifiable {
    let dateString: String
    let date: Date
    let noteFile: FolderFile?
    let transcriptFile: FolderFile?
    var id: String { dateString }
    var hasNote: Bool { noteFile != nil }
    var hasTranscript: Bool { transcriptFile != nil }

    static func scan(in dir: URL) async -> [MeetingDateEntry] {
        async let mdScan = DirectoryScanner.scanAsync(at: dir, fileExtension: "md")
        async let transcriptScan = DirectoryScanner.scanAsync(at: dir, fileExtension: "transcript")
        let mdFiles = await mdScan.files
        let transcriptFiles = await transcriptScan.files

        var dateMap: [String: (note: FolderFile?, transcript: FolderFile?)] = [:]
        for file in mdFiles {
            let datePrefix = file.url.deletingPathExtension().lastPathComponent
            guard datePrefix != "next" else { continue }
            let folderFile = FolderFile(id: file.url, name: datePrefix, date: file.date, url: file.url)
            dateMap[datePrefix, default: (nil, nil)].note = folderFile
        }
        for file in transcriptFiles {
            let datePrefix = file.url.deletingPathExtension().lastPathComponent
            let folderFile = FolderFile(id: file.url, name: datePrefix, date: file.date, url: file.url)
            dateMap[datePrefix, default: (nil, nil)].transcript = folderFile
        }

        let dateParser = DateFormatters.dayPOSIX
        return dateMap.map { key, value in
            let date = dateParser.date(from: key)
                ?? value.note?.date ?? value.transcript?.date ?? Date.distantPast
            return MeetingDateEntry(
                dateString: key, date: date,
                noteFile: value.note, transcriptFile: value.transcript
            )
        }
        .sorted { $0.dateString.localizedStandardCompare($1.dateString) == .orderedDescending }
    }
}

struct MoveDestination: Identifiable {
    let name: String
    let url: URL
    let section: String
    var id: String { url.path }
}

struct FolderFile: Identifiable, Hashable {
    let id: URL, name: String, date: Date, url: URL

    /// Read file contents off the main thread. Use this instead of a sync computed property
    /// so UI views never block on disk I/O.
    func loadContent() async -> String {
        let url = self.url
        return await Task.detached {
            do { return try String(contentsOf: url, encoding: .utf8) } catch {
                IssueLogger.log(.warning, "Failed to read folder file", context: url.path, error: error)
                return ""
            }
        }.value
    }

    func save(content: String) async {
        let url = self.url
        await Task.detached {
            do { try content.write(to: url, atomically: true, encoding: .utf8) } catch {
                IssueLogger.log(.error, "Failed to save folder file", context: url.path, error: error)
            }
        }.value
    }

    init(id: URL, name: String, date: Date, url: URL) {
        self.id = id; self.name = name; self.date = date; self.url = url
    }

    /// Lightweight init that avoids disk I/O. Callers that need the real modification date
    /// should use the full init with a date resolved via `DirectoryScanner` (off the main thread).
    init(url: URL) {
        self.id = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.date = Date()
        self.url = url
    }
}

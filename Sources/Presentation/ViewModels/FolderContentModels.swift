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
    let transcript: StoredTranscript?
    var id: String { dateString }
    var hasNote: Bool { noteFile != nil }
    var hasTranscript: Bool { transcript != nil }

    static func scan(in dir: URL, storage: FileTranscriptionStorage = FileTranscriptionStorage()) -> [MeetingDateEntry] {
        let mdFiles = DirectoryScanner.scan(at: dir, fileExtension: "md").files
        let transcriptFiles = DirectoryScanner.scan(at: dir, fileExtension: "transcript").files

        var dateMap: [String: (note: FolderFile?, transcript: StoredTranscript?)] = [:]

        for file in mdFiles {
            let datePrefix = file.url.deletingPathExtension().lastPathComponent
            guard datePrefix != "next" else { continue }
            let folderFile = FolderFile(id: file.url, name: datePrefix, date: file.date, url: file.url)
            dateMap[datePrefix, default: (nil, nil)].note = folderFile
        }

        for file in transcriptFiles {
            let datePrefix = file.url.deletingPathExtension().lastPathComponent
            if let parsed = storage.parseTranscriptFile(at: file.url) {
                dateMap[datePrefix, default: (nil, nil)].transcript = parsed
            }
        }

        let dateParser = DateFormatters.dayPOSIX

        return dateMap.map { key, value in
            let date = dateParser.date(from: key)
                ?? value.note?.date ?? value.transcript?.date ?? Date.distantPast
            return MeetingDateEntry(dateString: key, date: date, noteFile: value.note, transcript: value.transcript)
        }
        .sorted { $0.dateString.localizedStandardCompare($1.dateString) == .orderedDescending }
    }
}

struct FolderFile: Identifiable, Hashable {
    let id: URL, name: String, date: Date, url: URL
    var content: String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    func save(content: String) { try? content.write(to: url, atomically: true, encoding: .utf8) }

    init(id: URL, name: String, date: Date, url: URL) {
        self.id = id; self.name = name; self.date = date; self.url = url
    }

    init(url: URL) {
        self.id = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.date = (try? FileManager.default.attributesOfItem(
            atPath: url.path)[.modificationDate] as? Date) ?? Date()
        self.url = url
    }
}

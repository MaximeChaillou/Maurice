import Foundation

struct FolderItem: Identifiable {
    let name: String, url: URL, files: [FolderFile]
    var dateEntries: [MeetingDateEntry] = []
    var icon: String?
    var id: String { name }
    var fileCount: Int { max(files.count, dateEntries.count) }
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
}

struct FolderFile: Identifiable, Hashable {
    let id: URL, name: String, date: Date, url: URL
    var content: String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    func save(content: String) { try? content.write(to: url, atomically: true, encoding: .utf8) }
}

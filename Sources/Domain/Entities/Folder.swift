import Foundation

struct Folder: Identifiable, Sendable, Hashable {
    let url: URL
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

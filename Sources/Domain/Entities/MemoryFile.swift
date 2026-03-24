import Foundation

struct MemoryFile: Identifiable, Hashable {
    let id: URL
    let name: String
    let folder: String?
    let date: Date
    let url: URL

    var content: String {
        do { return try String(contentsOf: url, encoding: .utf8) } catch {
            IssueLogger.log(.warning, "Failed to read memory file", context: url.path, error: error)
            return ""
        }
    }

    /// YAML frontmatter block including the `---` delimiters.
    var frontmatter: String {
        let raw = content
        guard raw.hasPrefix("---") else { return "" }
        let lines = raw.components(separatedBy: "\n")
        guard let closeIndex = lines.dropFirst().firstIndex(of: "---") else { return "" }
        return lines[0...closeIndex].joined(separator: "\n")
    }

    /// Content without YAML frontmatter.
    var body: String {
        let raw = content
        guard raw.hasPrefix("---") else { return raw }
        let lines = raw.components(separatedBy: "\n")
        guard let closeIndex = lines.dropFirst().firstIndex(of: "---") else { return raw }
        return lines.dropFirst(closeIndex + 1)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save(body: String) {
        let fm = frontmatter
        let full = fm.isEmpty ? body : fm + "\n\n" + body
        do { try full.write(to: url, atomically: true, encoding: .utf8) } catch {
            IssueLogger.log(.error, "Failed to save memory file", context: url.path, error: error)
        }
    }
}

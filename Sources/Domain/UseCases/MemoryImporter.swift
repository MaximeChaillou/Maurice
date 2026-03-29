import Foundation

enum MemoryImporter {
    /// Copy all files and subdirectories from `source` into `destination`,
    /// overwriting existing files with the same name.
    static func importFolder(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        let items = try fm.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in items {
            let dest = destination.appendingPathComponent(item.lastPathComponent)
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                try importFolder(from: item, to: dest)
            } else {
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: item, to: dest)
            }
        }
    }
}

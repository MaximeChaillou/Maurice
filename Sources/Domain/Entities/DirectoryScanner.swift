import Foundation

enum DirectoryScanner {
    struct Contents: Sendable {
        let folders: [Folder]
        let files: [(url: URL, date: Date)]
    }

    static func scan(at directory: URL, fileExtension: String? = nil) -> Contents {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return Contents(folders: [], files: [])
        }

        var folders: [Folder] = []
        var files: [(url: URL, date: Date)] = []

        for item in items {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            if values?.isDirectory == true {
                folders.append(Folder(url: item))
            } else if fileExtension == nil || item.pathExtension == fileExtension {
                let date = values?.contentModificationDate ?? .distantPast
                files.append((url: item, date: date))
            }
        }

        folders.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return Contents(folders: folders, files: files)
    }

    static func scanRecursiveFiles(at directory: URL, fileExtension: String) -> [(url: URL, date: Date)] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var files: [(url: URL, date: Date)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == fileExtension else { continue }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            files.append((url: url, date: date))
        }
        return files
    }

    static func scanAsync(at directory: URL, fileExtension: String? = nil) async -> Contents {
        await Task.detached {
            scan(at: directory, fileExtension: fileExtension)
        }.value
    }
}

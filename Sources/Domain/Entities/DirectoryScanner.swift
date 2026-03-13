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

    static func scanAsync(at directory: URL, fileExtension: String? = nil) async -> Contents {
        await Task.detached {
            scan(at: directory, fileExtension: fileExtension)
        }.value
    }
}

import Foundation

protocol PersistentCodable: Codable {
    static var persistenceURL: URL { get }
    init()
}

extension PersistentCodable {
    static func load() -> Self {
        guard let data = try? Data(contentsOf: persistenceURL),
              let decoded = try? JSONDecoder().decode(Self.self, from: data)
        else { return Self() }
        return decoded
    }

    static func loadAsync() async -> Self {
        let url = persistenceURL
        let data = await Task.detached { try? Data(contentsOf: url) }.value
        guard let data, let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.persistenceURL, options: .atomic)
    }

    func saveAsync() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let url = Self.persistenceURL
        Task.detached {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Folder-relative persistence

protocol FolderPersistentCodable: Codable, Sendable {
    static var fileName: String { get }
    init()
}

extension FolderPersistentCodable {
    static func load(from folderURL: URL) -> Self {
        let url = folderURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Self.self, from: data)
        else { return Self() }
        return decoded
    }

    static func loadAsync(from folderURL: URL) async -> Self {
        let name = fileName
        return await Task.detached {
            let url = folderURL.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(Self.self, from: data)
            else { return Self() }
            return decoded
        }.value
    }

    func save(to folderURL: URL) {
        let url = folderURL.appendingPathComponent(Self.fileName)
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func saveAsync(to folderURL: URL) {
        let copy = self
        let name = Self.fileName
        Task.detached {
            let url = folderURL.appendingPathComponent(name)
            guard let data = try? JSONEncoder().encode(copy) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}

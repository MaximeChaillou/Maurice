import Foundation

protocol PersistentCodable: Codable {
    static var persistenceURL: URL { get }
    init()
}

extension PersistentCodable {
    static func load() -> Self {
        let url = persistenceURL
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            if !error.isFileNotFound {
                IssueLogger.log(.warning, "Failed to read persistence file", context: url.path, error: error)
            }
            return Self()
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            IssueLogger.log(.warning, "Failed to decode persistence file", context: url.path, error: error)
            return Self()
        }
    }

    static func loadAsync() async -> Self {
        let url = persistenceURL
        let result: Result<Data, Error> = await Task.detached {
            do {
                return .success(try Data(contentsOf: url))
            } catch {
                return .failure(error)
            }
        }.value
        let data: Data
        switch result {
        case .success(let value):
            data = value
        case .failure(let error):
            if !error.isFileNotFound {
                IssueLogger.log(.warning, "Failed to read persistence file (async)", context: url.path, error: error)
            }
            return Self()
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            IssueLogger.log(.warning, "Failed to decode persistence file (async)", context: url.path, error: error)
            return Self()
        }
    }

    func save() {
        let url = Self.persistenceURL
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            IssueLogger.log(.error, "Failed to save persistence file", context: url.path, error: error)
        }
    }

    func saveAsync() {
        guard let data = try? JSONEncoder().encode(self) else {
            IssueLogger.log(.error, "Failed to encode for async save", context: Self.persistenceURL.path)
            return
        }
        let url = Self.persistenceURL
        Task.detached {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                IssueLogger.log(.error, "Failed to write persistence file (async)", context: url.path, error: error)
            }
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
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return Self()
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            IssueLogger.log(.warning, "Failed to decode folder config", context: url.path, error: error)
            return Self()
        }
    }

    static func loadAsync(from folderURL: URL) async -> Self {
        let name = fileName
        return await Task.detached {
            let url = folderURL.appendingPathComponent(name)
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                return Self()
            }
            do {
                return try JSONDecoder().decode(Self.self, from: data)
            } catch {
                IssueLogger.log(.warning, "Failed to decode folder config (async)", context: url.path, error: error)
                return Self()
            }
        }.value
    }

    func save(to folderURL: URL) {
        let url = folderURL.appendingPathComponent(Self.fileName)
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            IssueLogger.log(.error, "Failed to save folder config", context: url.path, error: error)
        }
    }

    func saveAsync(to folderURL: URL) {
        let copy = self
        let name = Self.fileName
        Task.detached {
            let url = folderURL.appendingPathComponent(name)
            do {
                let data = try JSONEncoder().encode(copy)
                try data.write(to: url, options: .atomic)
            } catch {
                IssueLogger.log(.error, "Failed to save folder config (async)", context: url.path, error: error)
            }
        }
    }
}

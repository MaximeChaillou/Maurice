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

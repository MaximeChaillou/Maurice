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

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.persistenceURL, options: .atomic)
    }
}

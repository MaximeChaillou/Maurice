import Foundation

/// Centralized store for all meeting configurations.
///
/// All configs live in a single JSON file (`.maurice/meeting_configs.json`),
/// keyed by the folder's path relative to `AppSettings.rootDirectory`
/// (e.g. `Meetings/Standup`, `People/Team/Alice/1-1`).
final class MeetingConfigStore: @unchecked Sendable {
    static let shared = MeetingConfigStore()

    private let lock = NSLock()
    private var configs: [String: MeetingConfig] = [:]

    private init() {}

    // MARK: - Bootstrap

    /// Loads the store from disk, running migration from per-folder
    /// `.config.json` files if the central file does not yet exist.
    /// Safe to call multiple times — subsequent calls are no-ops.
    func bootstrap() async {
        let url = AppSettings.meetingConfigsURL
        let migrated: [String: MeetingConfig] = await Task.detached {
            if FileManager.default.fileExists(atPath: url.path) {
                return Self.loadFromDisk(at: url)
            }
            let configs = Self.migrateLegacyConfigs()
            Self.writeToDisk(configs, to: url)
            return configs
        }.value
        replace(with: migrated)
    }

    /// Drops cached state. Call when `AppSettings.rootDirectory` changes
    /// so the next access re-bootstraps from the new location.
    func reset() {
        withLock { configs = [:] }
    }

    // MARK: - Access

    func config(for folderURL: URL) -> MeetingConfig {
        let key = Self.relativeKey(for: folderURL)
        return withLock { configs[key] ?? MeetingConfig() }
    }

    func update(_ config: MeetingConfig, for folderURL: URL) {
        let key = Self.relativeKey(for: folderURL)
        let snapshot: [String: MeetingConfig] = withLock {
            configs[key] = config
            return configs
        }
        persist(snapshot)
    }

    /// Removes the config for `folderURL` and any descendants
    /// (e.g. deleting a person folder removes its `1-1` config too).
    func remove(for folderURL: URL) {
        let key = Self.relativeKey(for: folderURL)
        let prefix = key.isEmpty ? "" : key + "/"
        let snapshot: [String: MeetingConfig] = withLock {
            configs = configs.filter { entry in
                entry.key != key && (prefix.isEmpty || !entry.key.hasPrefix(prefix))
            }
            return configs
        }
        persist(snapshot)
    }

    /// Re-keys the config for `oldURL` (and any descendants) under `newURL`.
    func move(from oldURL: URL, to newURL: URL) {
        let oldKey = Self.relativeKey(for: oldURL)
        let newKey = Self.relativeKey(for: newURL)
        guard oldKey != newKey else { return }
        let oldPrefix = oldKey.isEmpty ? "" : oldKey + "/"
        let newPrefix = newKey.isEmpty ? "" : newKey + "/"
        let snapshot: [String: MeetingConfig] = withLock {
            var updated: [String: MeetingConfig] = [:]
            for (key, value) in configs {
                if key == oldKey {
                    updated[newKey] = value
                } else if !oldPrefix.isEmpty, key.hasPrefix(oldPrefix) {
                    updated[newPrefix + key.dropFirst(oldPrefix.count)] = value
                } else {
                    updated[key] = value
                }
            }
            configs = updated
            return configs
        }
        persist(snapshot)
    }

    private func replace(with newConfigs: [String: MeetingConfig]) {
        withLock { configs = newConfigs }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Key derivation

    static func relativeKey(for folderURL: URL) -> String {
        let root = AppSettings.rootDirectory.standardizedFileURL.path
        let folder = folderURL.standardizedFileURL.path
        if folder == root { return "" }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        if folder.hasPrefix(prefix) {
            return String(folder.dropFirst(prefix.count))
        }
        return folder
    }

    // MARK: - Disk I/O

    private func persist(_ snapshot: [String: MeetingConfig]) {
        let url = AppSettings.meetingConfigsURL
        Task.detached {
            Self.writeToDisk(snapshot, to: url)
        }
    }

    private static func loadFromDisk(at url: URL) -> [String: MeetingConfig] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: MeetingConfig].self, from: data)
        } catch {
            IssueLogger.log(.warning, "Failed to read meeting configs", context: url.path, error: error)
            return [:]
        }
    }

    private static func writeToDisk(_ snapshot: [String: MeetingConfig], to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            IssueLogger.log(.error, "Failed to write meeting configs", context: url.path, error: error)
        }
    }

    // MARK: - Migration

    private static let legacyFileName = ".config.json"

    private static func migrateLegacyConfigs() -> [String: MeetingConfig] {
        let fm = FileManager.default
        var configs: [String: MeetingConfig] = [:]
        var legacyURLs: [URL] = []

        for root in [AppSettings.meetingsDirectory, AppSettings.peopleDirectory] {
            guard fm.fileExists(atPath: root.path) else { continue }
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: []
            ) else {
                IssueLogger.log(.warning, "Failed to enumerate legacy configs", context: root.path)
                continue
            }

            for case let url as URL in enumerator
                where url.lastPathComponent == legacyFileName {
                let data: Data
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    IssueLogger.log(.warning, "Failed to read legacy config", context: url.path, error: error)
                    continue
                }
                let config: MeetingConfig
                do {
                    config = try JSONDecoder().decode(MeetingConfig.self, from: data)
                } catch {
                    IssueLogger.log(.warning, "Failed to decode legacy config", context: url.path, error: error)
                    continue
                }
                let key = relativeKey(for: url.deletingLastPathComponent())
                configs[key] = config
                legacyURLs.append(url)
            }
        }

        for url in legacyURLs {
            do {
                try fm.removeItem(at: url)
            } catch {
                IssueLogger.log(.warning, "Failed to delete legacy config", context: url.path, error: error)
            }
        }
        return configs
    }
}

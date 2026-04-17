import Foundation

extension Notification.Name {
    static let fileSystemDidChange = Notification.Name("fileSystemDidChange")
}

extension Notification {
    /// Absolute paths reported by FSEvents for this notification, or nil when unavailable.
    var changedPaths: [String]? { userInfo?["paths"] as? [String] }

    /// True when at least one reported path equals `url.path` or lives inside it.
    /// When no path info is available, returns `true` so handlers still refresh defensively.
    func affectsPath(_ url: URL) -> Bool {
        guard let paths = changedPaths else { return true }
        let target = url.standardizedFileURL.path
        return paths.contains { changed in
            let normalized = URL(fileURLWithPath: changed).standardizedFileURL.path
            return normalized == target || normalized.hasPrefix(target + "/")
        }
    }
}

final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let path: String
    private let debounceInterval: TimeInterval

    init(path: String, debounceInterval: TimeInterval = 2.0) {
        self.path = path
        self.debounceInterval = debounceInterval
    }

    func start() {
        guard stream == nil else { return }
        let pathCF = [path] as CFArray

        var context = FSEventStreamContext()

        let callback: FSEventStreamCallback = { _, _, _, eventPaths, _, _ in
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
            NotificationCenter.default.post(
                name: .fileSystemDidChange, object: nil, userInfo: ["paths": paths]
            )
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathCF,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            debounceInterval,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}

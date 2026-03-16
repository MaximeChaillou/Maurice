import Foundation

final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let path: String
    private let debounceInterval: TimeInterval

    init(path: String, debounceInterval: TimeInterval = 1.0) {
        self.path = path
        self.debounceInterval = debounceInterval
    }

    func start() {
        guard stream == nil else { return }
        let pathCF = [path] as CFArray

        var context = FSEventStreamContext()

        let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
            NotificationCenter.default.post(name: .fileSystemDidChange, object: nil)
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

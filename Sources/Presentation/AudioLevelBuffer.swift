import Foundation

final class AudioLevelBuffer: Sendable {
    private let lock = NSLock()
    private let maxCount: Int
    nonisolated(unsafe) private var levels: [Float] = []

    // Display state — only accessed from main thread via snapshot()/reset()
    nonisolated(unsafe) private var displayLevels: [Float] = []
    nonisolated(unsafe) private var lastSnapshotTime: TimeInterval = 0

    init(maxCount: Int = 50) {
        self.maxCount = maxCount
    }

    func append(_ level: Float) {
        lock.lock()
        levels.append(level)
        if levels.count > maxCount {
            levels.removeFirst(levels.count - maxCount)
        }
        lock.unlock()
    }

    /// Call from main thread only (TimelineView canvas).
    func snapshot() -> [Float] {
        // Copy raw levels under lock (fast)
        lock.lock()
        let target = levels
        lock.unlock()

        // Lerp computation outside lock — no contention with audio thread
        let now = ProcessInfo.processInfo.systemUptime
        let dt = Float(min(now - lastSnapshotTime, 0.1))
        lastSnapshotTime = now

        while displayLevels.count < target.count {
            displayLevels.append(0)
        }
        if displayLevels.count > target.count {
            displayLevels.removeFirst(displayLevels.count - target.count)
        }

        let alpha = min(dt * 15, 1.0)
        for i in 0..<target.count {
            displayLevels[i] += (target[i] - displayLevels[i]) * alpha
        }

        return displayLevels
    }

    func reset() {
        lock.lock()
        levels.removeAll()
        lock.unlock()
        displayLevels.removeAll()
        lastSnapshotTime = 0
    }
}

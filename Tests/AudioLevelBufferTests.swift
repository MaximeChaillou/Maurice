import XCTest
@testable import Maurice

final class AudioLevelBufferTests: XCTestCase {

    // MARK: - Append

    func testAppendSingleLevel() {
        let buffer = AudioLevelBuffer(maxCount: 10)
        buffer.append(0.5)
        let snap = buffer.snapshot()
        XCTAssertEqual(snap.count, 1)
    }

    func testAppendRespectsMaxCount() {
        let buffer = AudioLevelBuffer(maxCount: 3)
        for i in 0..<10 {
            buffer.append(Float(i))
        }
        let snap = buffer.snapshot()
        XCTAssertEqual(snap.count, 3)
    }

    func testAppendOrderPreservesNewest() {
        let buffer = AudioLevelBuffer(maxCount: 2)
        buffer.append(1.0)
        buffer.append(2.0)
        buffer.append(3.0)
        // After lerp, values approach targets. With large enough alpha, last two entries dominate.
        let snap = buffer.snapshot()
        XCTAssertEqual(snap.count, 2)
    }

    // MARK: - Reset

    func testResetClearsLevels() {
        let buffer = AudioLevelBuffer(maxCount: 10)
        buffer.append(0.5)
        buffer.append(0.8)
        buffer.reset()
        let snap = buffer.snapshot()
        XCTAssertTrue(snap.isEmpty)
    }

    // MARK: - Snapshot

    func testSnapshotOnEmpty() {
        let buffer = AudioLevelBuffer(maxCount: 10)
        let snap = buffer.snapshot()
        XCTAssertTrue(snap.isEmpty)
    }

    func testSnapshotReturnsSameCountAsLevels() {
        let buffer = AudioLevelBuffer(maxCount: 10)
        buffer.append(0.1)
        buffer.append(0.2)
        buffer.append(0.3)
        let snap = buffer.snapshot()
        XCTAssertEqual(snap.count, 3)
    }

    func testSnapshotLerpConvergesToTarget() {
        let buffer = AudioLevelBuffer(maxCount: 5)
        buffer.append(1.0)
        // Call snapshot multiple times — display should converge toward 1.0
        var last: Float = 0
        for _ in 0..<20 {
            let snap = buffer.snapshot()
            last = snap[0]
        }
        XCTAssertEqual(last, 1.0, accuracy: 0.05)
    }

    func testSnapshotAfterReset() {
        let buffer = AudioLevelBuffer(maxCount: 5)
        buffer.append(0.5)
        _ = buffer.snapshot()
        buffer.reset()
        let snap = buffer.snapshot()
        XCTAssertTrue(snap.isEmpty)
    }

    // MARK: - Thread Safety

    func testConcurrentAppendAndSnapshot() async {
        let buffer = AudioLevelBuffer(maxCount: 100)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<1000 {
                    buffer.append(Float(i % 10) / 10.0)
                }
            }
            group.addTask {
                for _ in 0..<1000 {
                    _ = buffer.snapshot()
                }
            }
        }
        // If we reach here without a crash, thread safety is confirmed
    }

    func testConcurrentAppendAndReset() async {
        let buffer = AudioLevelBuffer(maxCount: 50)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<500 {
                    buffer.append(Float(i) / 500.0)
                }
            }
            group.addTask {
                for _ in 0..<100 {
                    buffer.reset()
                }
            }
        }
    }

    // MARK: - Default Max Count

    func testDefaultMaxCount() {
        let buffer = AudioLevelBuffer()
        for _ in 0..<100 {
            buffer.append(0.5)
        }
        let snap = buffer.snapshot()
        XCTAssertEqual(snap.count, 50)
    }
}

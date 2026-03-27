import XCTest
@testable import Maurice

final class SpeechModelStateTests: XCTestCase {

    func testIdleStatusText() {
        XCTAssertEqual(SpeechModelState.idle.statusText, "Ready")
    }

    func testDownloadingStatusText() {
        let state = SpeechModelState.downloading(progress: 0.5)
        XCTAssertEqual(state.statusText, "Downloading model… 50%")
    }

    func testDownloadingStatusTextZero() {
        let state = SpeechModelState.downloading(progress: 0.0)
        XCTAssertEqual(state.statusText, "Downloading model… 0%")
    }

    func testDownloadingStatusTextFull() {
        let state = SpeechModelState.downloading(progress: 1.0)
        XCTAssertEqual(state.statusText, "Downloading model… 100%")
    }

    func testLoadingStatusText() {
        XCTAssertEqual(SpeechModelState.loading.statusText, "Loading model…")
    }

    func testReadyStatusText() {
        XCTAssertEqual(SpeechModelState.ready.statusText, "Model loaded")
    }

    func testFailedStatusText() {
        let state = SpeechModelState.failed("Mic access denied")
        XCTAssertEqual(state.statusText, "Mic access denied")
    }
}

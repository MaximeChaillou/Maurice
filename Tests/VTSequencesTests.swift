import XCTest
@testable import Maurice

final class VTSequencesTests: XCTestCase {

    // MARK: - Arrow keys

    func testUpArrowSequence() {
        let seq = vtSequencesMap[126]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x41], "Up arrow should be ESC [ A")
    }

    func testDownArrowSequence() {
        let seq = vtSequencesMap[125]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x42], "Down arrow should be ESC [ B")
    }

    func testRightArrowSequence() {
        let seq = vtSequencesMap[124]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x43], "Right arrow should be ESC [ C")
    }

    func testLeftArrowSequence() {
        let seq = vtSequencesMap[123]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x44], "Left arrow should be ESC [ D")
    }

    // MARK: - Navigation keys

    func testHomeSequence() {
        let seq = vtSequencesMap[115]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x48], "Home should be ESC [ H")
    }

    func testEndSequence() {
        let seq = vtSequencesMap[119]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x46], "End should be ESC [ F")
    }

    func testPageUpSequence() {
        let seq = vtSequencesMap[116]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x35, 0x7E], "PageUp should be ESC [ 5 ~")
    }

    func testPageDownSequence() {
        let seq = vtSequencesMap[121]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x36, 0x7E], "PageDown should be ESC [ 6 ~")
    }

    func testDeleteSequence() {
        let seq = vtSequencesMap[117]
        XCTAssertEqual(seq, [0x1B, 0x5B, 0x33, 0x7E], "Delete should be ESC [ 3 ~")
    }

    // MARK: - Unknown key

    func testUnknownKeyReturnsNil() {
        XCTAssertNil(vtSequencesMap[999])
    }

    func testAllSequencesStartWithESC() {
        for (_, seq) in vtSequencesMap {
            XCTAssertEqual(seq.first, 0x1B, "All VT sequences should start with ESC")
        }
    }
}

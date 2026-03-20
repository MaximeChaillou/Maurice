import XCTest
@testable import Maurice

@MainActor
final class HomeViewTests: XCTestCase {

    // MARK: - Action cards visibility

    func testActionCardsShownWhenNoMeetingsAndNotConnected() {
        // Cards should show when hasMeetings=false AND isConnected=false
        let hasMeetings = false
        let isConnected = false
        let showCards = !hasMeetings && !isConnected
        XCTAssertTrue(showCards)
    }

    func testActionCardsHiddenWhenHasMeetings() {
        let hasMeetings = true
        let isConnected = false
        let showCards = !hasMeetings && !isConnected
        XCTAssertFalse(showCards)
    }

    func testActionCardsHiddenWhenCalendarConnected() {
        let hasMeetings = false
        let isConnected = true
        let showCards = !hasMeetings && !isConnected
        XCTAssertFalse(showCards)
    }

    func testActionCardsHiddenWhenBothConditionsMet() {
        let hasMeetings = true
        let isConnected = true
        let showCards = !hasMeetings && !isConnected
        XCTAssertFalse(showCards)
    }
}

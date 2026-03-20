import XCTest
@testable import Maurice

@MainActor
final class NavigationCoordinatorTests: XCTestCase {

    func testDefaultState() {
        let coordinator = NavigationCoordinator()
        XCTAssertEqual(coordinator.activeTab, .meeting)
        XCTAssertTrue(coordinator.showHome)
    }

    func testSwitchTab() {
        let coordinator = NavigationCoordinator()
        coordinator.activeTab = .people
        XCTAssertEqual(coordinator.activeTab, .people)
    }

    func testShowHomeFalseWhenNavigating() {
        let coordinator = NavigationCoordinator()
        coordinator.showHome = false
        coordinator.activeTab = .task
        XCTAssertFalse(coordinator.showHome)
        XCTAssertEqual(coordinator.activeTab, .task)
    }
}

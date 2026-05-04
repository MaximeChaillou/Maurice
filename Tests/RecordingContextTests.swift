import XCTest
@testable import Maurice

@MainActor
final class RecordingContextTests: XCTestCase {

    private var tempDir: URL!
    private var originalRootDirectory: String?

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        originalRootDirectory = UserDefaults.standard.string(forKey: "rootDirectory")
        UserDefaults.standard.set(tempDir.path, forKey: "rootDirectory")
        MeetingConfigStore.shared.reset()
    }

    override func tearDown() async throws {
        MeetingConfigStore.shared.reset()
        if let original = originalRootDirectory {
            UserDefaults.standard.set(original, forKey: "rootDirectory")
        } else {
            UserDefaults.standard.removeObject(forKey: "rootDirectory")
        }
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private struct Harness {
        let context: RecordingContext
        let recordingViewModel: RecordingViewModel
        let meetingViewModel: MeetingsViewModel
        let peopleViewModel: PeopleContentViewModel
        let coordinator: NavigationCoordinator
    }

    private func makeHarness() -> Harness {
        let useCase = RecordingUseCase(
            transcription: MockLiveTranscriptionService(),
            storage: StubTranscriptionStorage()
        )
        let recordingVM = RecordingViewModel(recordingUseCase: useCase)
        let calendarVM = GoogleCalendarViewModel(
            calendarService: MockCalendarService(),
            tokenStore: MockTokenStore()
        )
        let meetingsDir = tempDir.appendingPathComponent("Meetings", isDirectory: true)
        let peopleDir = tempDir.appendingPathComponent("People", isDirectory: true)
        try? FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: peopleDir, withIntermediateDirectories: true)
        let meetingVM = MeetingsViewModel(directory: meetingsDir)
        let peopleVM = PeopleContentViewModel(directory: peopleDir)
        let coordinator = NavigationCoordinator()
        let context = RecordingContext(
            recordingViewModel: recordingVM,
            calendarViewModel: calendarVM,
            meetingViewModel: meetingVM,
            peopleViewModel: peopleVM,
            navigationCoordinator: coordinator
        )
        return Harness(
            context: context, recordingViewModel: recordingVM,
            meetingViewModel: meetingVM, peopleViewModel: peopleVM,
            coordinator: coordinator
        )
    }

    /// Regression: from Home, "Start recording" must create a new meeting
    /// folder rather than re-using `selectedFolder` (which can be auto-set
    /// by MeetingsView when the user previously visited the tab).
    func testRecordTapFromHomeCreatesNewMeetingEvenIfFolderSelected() async throws {
        let harness = makeHarness()

        let existing = harness.meetingViewModel.directory
            .appendingPathComponent("Existing", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        harness.meetingViewModel.selectedFolder = "Existing"
        harness.coordinator.showHome = true
        harness.coordinator.activeTab = .meeting

        harness.context.handleRecordTap()
        try await Task.sleep(for: .milliseconds(300))

        let selected = harness.meetingViewModel.selectedFolder ?? ""
        XCTAssertNotEqual(selected, "Existing")
        let today = DateFormatters.dayOnly.string(from: Date())
        XCTAssertTrue(selected.contains(today),
                      "Expected new dated folder, got '\(selected)'")
        XCTAssertEqual(harness.recordingViewModel.subdirectory, selected)
        XCTAssertFalse(harness.coordinator.showHome)
    }

    /// When already inside the Meeting tab with a folder selected, recording
    /// should append to that folder instead of creating a new one.
    func testRecordTapFromMeetingTabReusesSelectedFolder() async throws {
        let harness = makeHarness()

        let standup = harness.meetingViewModel.directory
            .appendingPathComponent("Standup", isDirectory: true)
        try FileManager.default.createDirectory(at: standup, withIntermediateDirectories: true)
        harness.meetingViewModel.selectedFolder = "Standup"
        harness.coordinator.showHome = false
        harness.coordinator.activeTab = .meeting

        harness.context.handleRecordTap()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(harness.recordingViewModel.subdirectory, "Standup")
        XCTAssertEqual(harness.meetingViewModel.selectedFolder, "Standup")
    }
}

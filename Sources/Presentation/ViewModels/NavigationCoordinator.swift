import SwiftUI

enum AppTab: String, CaseIterable {
    case meeting
    case people
    case task
}

@MainActor @Observable
final class NavigationCoordinator {
    var activeTab: AppTab = .meeting

    // Per-tab selection (preserves open file when switching tabs)
    var selectedMeeting: String?
    var selectedPerson: String?
    var meetingFileIndex: Int = 0
}

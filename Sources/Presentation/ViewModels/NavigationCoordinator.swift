import SwiftUI

enum AppTab: String, CaseIterable {
    case meeting
    case people
    case task
}

@MainActor @Observable
final class NavigationCoordinator {
    var activeTab: AppTab = .meeting
    var showHome: Bool = true
}

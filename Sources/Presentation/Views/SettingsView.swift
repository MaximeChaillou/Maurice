import SwiftUI

@Observable
@MainActor
final class SettingsNavigator {
    var selectedSection: SettingsSection? = .general
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case calendar
    case skills
    case templateUpdates
    case mcp
    case claudeMD

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .general: String(localized: "General")
        case .calendar: String(localized: "Google Calendar")
        case .skills: String(localized: "Skills")
        case .templateUpdates: String(localized: "Template updates")
        case .mcp: String(localized: "MCP Servers")
        case .claudeMD: String(localized: "CLAUDE.md")
        }
    }

    var icon: String {
        switch self {
        case .general: "folder"
        case .calendar: "calendar.badge.clock"
        case .skills: "terminal"
        case .templateUpdates: "arrow.triangle.2.circlepath"
        case .mcp: "server.rack"
        case .claudeMD: "doc.text"
        }
    }
}

struct SettingsView: View {
    var calendarViewModel: GoogleCalendarViewModel?
    @ObservedObject var updateChecker: UpdateChecker
    var templateUpdateService: TemplateUpdateService
    @Bindable var navigator: SettingsNavigator
    var onRootDirectoryChanged: (() -> Void)?

    var body: some View {
        HSplitView {
            settingsSidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 250)

            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var settingsSidebar: some View {
        List(selection: $navigator.selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                HStack(spacing: 6) {
                    Label(section.localizedName, systemImage: section.icon)
                    Spacer()
                    if section == .templateUpdates, templateUpdateService.hasPendingUpdates {
                        Circle().fill(.orange).frame(width: 7, height: 7)
                    }
                }
                .tag(section)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var settingsDetail: some View {
        switch navigator.selectedSection {
        case .general:
            GeneralSettingsView(updateChecker: updateChecker, onRootDirectoryChanged: onRootDirectoryChanged)
        case .calendar:
            if let calendarViewModel {
                GoogleCalendarSettingsView(viewModel: calendarViewModel)
            }
        case .skills:
            SkillsSettingsView(markdownTheme: MarkdownTheme())
        case .templateUpdates:
            TemplateUpdatesView(
                service: templateUpdateService,
                rootDirectory: AppSettings.rootDirectory
            )
        case .mcp:
            MCPServersView()
        case .claudeMD:
            ClaudeMDView(markdownTheme: MarkdownTheme())
        case .none:
            ContentUnavailableView(
                "No section selected",
                systemImage: "gearshape",
                description: Text("Select a section from the list.")
            )
        }
    }
}

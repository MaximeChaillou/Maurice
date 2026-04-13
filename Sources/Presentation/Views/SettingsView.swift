import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case calendar
    case background
    case appearance
    case skills
    case templateUpdates
    case mcp
    case claudeMD

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .general: String(localized: "General")
        case .calendar: String(localized: "Google Calendar")
        case .background: String(localized: "Background")
        case .appearance: String(localized: "Markdown style")
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
        case .background: "paintpalette"
        case .appearance: "paintbrush"
        case .skills: "terminal"
        case .templateUpdates: "arrow.triangle.2.circlepath"
        case .mcp: "server.rack"
        case .claudeMD: "doc.text"
        }
    }
}

struct SettingsView: View {
    @Binding var appTheme: AppTheme
    var calendarViewModel: GoogleCalendarViewModel?
    @ObservedObject var updateChecker: UpdateChecker
    var templateUpdateService: TemplateUpdateService
    var onRootDirectoryChanged: (() -> Void)?
    @State private var selectedSection: SettingsSection? = .general

    var body: some View {
        HSplitView {
            settingsSidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 250)

            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var settingsSidebar: some View {
        List(selection: $selectedSection) {
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
        switch selectedSection {
        case .general:
            GeneralSettingsView(updateChecker: updateChecker, onRootDirectoryChanged: onRootDirectoryChanged)
        case .calendar:
            if let calendarViewModel {
                GoogleCalendarSettingsView(viewModel: calendarViewModel)
            }
        case .background:
            BackgroundSettingsView(appTheme: $appTheme)
        case .appearance:
            MarkdownThemeSettingsView(theme: $appTheme.markdown)
        case .skills:
            SkillsSettingsView(markdownTheme: appTheme.markdown)
        case .templateUpdates:
            TemplateUpdatesView(
                service: templateUpdateService,
                rootDirectory: AppSettings.rootDirectory
            )
        case .mcp:
            MCPServersView()
        case .claudeMD:
            ClaudeMDView(markdownTheme: appTheme.markdown)
        case .none:
            ContentUnavailableView(
                "No section selected",
                systemImage: "gearshape",
                description: Text("Select a section from the list.")
            )
        }
    }
}

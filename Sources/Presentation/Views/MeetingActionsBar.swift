import SwiftUI

/// Shared trailing-actions row for the doc header of any "schedulable folder"
/// (a meeting folder or a 1-1 folder). Renders the QuickNotes pill + Skills
/// pill, and owns the config / add-action sheets driven from the Skills menu.
///
/// The caller passes a binding to the `MeetingConfig` so any change made
/// through the sheets stays in sync with state used elsewhere in the parent
/// (e.g. the breadcrumb's calendar event lookup).
struct MeetingActionsBar: View {
    let folderURL: URL
    let folderDisplayName: String
    let consoleViewModel: ConsoleViewModel?
    @Binding var config: MeetingConfig
    var activeFilePath: String?

    @State private var showConfigSheet = false

    var body: some View {
        HStack(spacing: 6) {
            QuickNotesPillButton(fileURL: folderURL.appendingPathComponent("next.md"))
            if let console = consoleViewModel {
                SkillsPillMenu(
                    config: config,
                    consoleViewModel: console,
                    activeFilePath: activeFilePath,
                    onConfigure: { showConfigSheet = true }
                )
            }
        }
        .sheet(isPresented: $showConfigSheet) { configSheet }
    }

    @ViewBuilder
    private var configSheet: some View {
        if let console = consoleViewModel {
            MeetingConfigSheet(
                folderName: folderDisplayName,
                folderURL: folderURL,
                config: $config,
                consoleViewModel: console
            )
            .frame(width: 520, height: 560)
        }
    }
}

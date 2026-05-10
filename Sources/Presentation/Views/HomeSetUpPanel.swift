import SwiftUI

struct HomeSetUpPanel: View {
    let checker: HomeSetupChecker
    let templateUpdateService: TemplateUpdateService
    let settingsNavigator: SettingsNavigator
    @Environment(\.openWindow) private var openWindow

    private var memoryDone: Bool { checker.memoryStatus.isComplete }
    private var consoleDone: Bool {
        if case .ok = checker.consoleState { return true }
        return false
    }
    private var configDone: Bool { !templateUpdateService.hasPendingUpdates }
    private var doneCount: Int {
        (memoryDone ? 1 : 0) + (consoleDone ? 1 : 0) + (configDone ? 1 : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Set up")
                    .font(.system(size: 13.5, weight: .semibold))
                Spacer()
                HomeProgressIndicator(done: doneCount, total: 3)
            }

            VStack(spacing: 4) {
                HomeSetupRow(
                    label: String(localized: "Memory imported"),
                    detail: memoryDetail,
                    state: memoryRowState,
                    action: { openWindow(id: "memory") }
                )
                HomeSetupRow(
                    label: String(localized: "Claude CLI ready"),
                    detail: consoleDetail,
                    state: consoleRowState,
                    action: { Task { await checker.refreshConsole() } }
                )
                HomeSetupRow(
                    label: String(localized: "Configuration up to date"),
                    detail: configDetail,
                    state: configDone ? .done : .pending,
                    action: openTemplateUpdates
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var memoryRowState: HomeSetupRow.State {
        let status = checker.memoryStatus
        if status.isComplete { return .done }
        if status.presentCount > 0 { return .partial }
        return .pending
    }

    private var memoryDetail: String? {
        let status = checker.memoryStatus
        if status.isComplete { return nil }
        return String(localized: "\(status.presentCount)/\(status.totalCount) files")
    }

    private var consoleRowState: HomeSetupRow.State {
        switch checker.consoleState {
        case .checking: return .checking
        case .ok: return .done
        case .failed: return .pending
        }
    }

    private var consoleDetail: String? {
        switch checker.consoleState {
        case .checking:
            return String(localized: "Checking…")
        case .ok(let version):
            return version.isEmpty ? nil : version
        case .failed(let reason):
            return reason
        }
    }

    private var configDetail: String? {
        let count = templateUpdateService.pendingTemplates.count
        guard count > 0 else { return nil }
        return String(localized: "\(count) update(s) pending")
    }

    private func openTemplateUpdates() {
        settingsNavigator.selectedSection = .templateUpdates
        openWindow(id: "settings")
    }
}

struct HomeSetupRow: View {
    enum State { case done, partial, pending, checking }

    let label: String
    let detail: String?
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                indicator
                Text(label)
                    .font(.system(size: 12.5))
                    .strikethrough(state == .done, color: .secondary)
                    .foregroundStyle(state == .done ? .secondary : .primary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { background }
            .opacity(state == .done ? 0.55 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(state == .done)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .done:
            ZStack {
                Circle().fill(Color.cyan).frame(width: 14, height: 14)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        case .partial:
            ZStack {
                Circle()
                    .strokeBorder(Color.orange, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(Color.orange.opacity(0.55))
                    .frame(width: 7, height: 7)
            }
        case .checking:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 14, height: 14)
        case .pending:
            Circle()
                .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                .frame(width: 14, height: 14)
        }
    }

    @ViewBuilder
    private var background: some View {
        if state != .done {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

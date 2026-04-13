import Foundation
import Sparkle

@MainActor
final class UpdateChecker: ObservableObject {
    let updater: SPUUpdater
    private let loggingDelegate = UpdateLoggingDelegate()

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: loggingDelegate,
            userDriverDelegate: nil
        )
        self.updater = controller.updater
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

/// Routes every Sparkle error (feed fetch, signature, download, install, relaunch, …)
/// to `IssueLogger` so auto-update failures are never silent.
/// Benign "no update available" and "user canceled" cases are filtered out.
@MainActor
private final class UpdateLoggingDelegate: NSObject, SPUUpdaterDelegate {
    // Raw codes from SUErrors.h — kept as Ints to avoid coupling to Swift enum renaming.
    private static let benignSparkleCodes: Set<Int> = [
        1001, // SUNoUpdateError — no update available (expected)
        4007  // SUInstallationCanceledError — user canceled auth prompt (expected)
    ]

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        logIfRelevant(error, context: "Update aborted")
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        guard let error else { return }
        logIfRelevant(error, context: "Update cycle failed (\(Self.describe(updateCheck)))")
    }

    private func logIfRelevant(_ error: Error, context: String) {
        let nsError = error as NSError
        if nsError.domain == SUSparkleErrorDomain,
           Self.benignSparkleCodes.contains(nsError.code) {
            return
        }
        IssueLogger.log(.error, context, error: error)
    }

    private static func describe(_ check: SPUUpdateCheck) -> String {
        switch check {
        case .updates: "user"
        case .updatesInBackground: "background"
        case .updateInformation: "info"
        @unknown default: "unknown"
        }
    }
}

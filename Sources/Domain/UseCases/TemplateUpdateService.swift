import CryptoKit
import Foundation
import Observation

/// Reconciles bundled skill templates against user copies.
///
/// Each tracked template has a baseline hash stored in
/// `.maurice/template_baselines.json` that represents the last bundled
/// version we compared against. On each launch:
/// - if the bundled hash matches the baseline, nothing happens;
/// - if the user never touched their copy (user hash == baseline), we
///   silently overwrite with the new bundled version;
/// - if the user customized their copy, we flag it so they can review
///   the diff and decide.
@MainActor
@Observable
final class TemplateUpdateService {
    struct TemplateDescriptor: Identifiable, Hashable, Sendable {
        let name: String
        let bundleResource: String
        let userFileURL: URL
        var id: String { name }
    }

    typealias BundleLoader = @Sendable (String) -> Data?

    private(set) var pendingTemplates: [TemplateDescriptor] = []

    var hasPendingUpdates: Bool { !pendingTemplates.isEmpty }

    private let bundleLoader: BundleLoader

    init(bundleLoader: @escaping BundleLoader = TemplateUpdateService.defaultBundleLoader) {
        self.bundleLoader = bundleLoader
    }

    // MARK: - Public API

    nonisolated static func descriptors(rootDirectory: URL) -> [TemplateDescriptor] {
        let commands = rootDirectory.appendingPathComponent(".claude/commands")
        return [
            TemplateDescriptor(
                name: "CLAUDE.md",
                bundleResource: "CLAUDE",
                userFileURL: rootDirectory.appendingPathComponent("CLAUDE.md")
            ),
            TemplateDescriptor(
                name: "prepare-meeting.md",
                bundleResource: "prepare-meeting",
                userFileURL: commands.appendingPathComponent("prepare-meeting.md")
            ),
            TemplateDescriptor(
                name: "summarize-meeting.md",
                bundleResource: "summarize-meeting",
                userFileURL: commands.appendingPathComponent("summarize-meeting.md")
            ),
            TemplateDescriptor(
                name: "maurice-convert-file-to-md.md",
                bundleResource: "maurice-convert-file-to-md",
                userFileURL: commands.appendingPathComponent("maurice-convert-file-to-md.md")
            ),
        ]
    }

    nonisolated static func baselinesURL(rootDirectory: URL) -> URL {
        rootDirectory.appendingPathComponent(".maurice/template_baselines.json")
    }

    func reconcile(rootDirectory: URL, descriptors: [TemplateDescriptor]? = nil) async {
        let resolved = descriptors ?? Self.descriptors(rootDirectory: rootDirectory)
        let baselinesFile = Self.baselinesURL(rootDirectory: rootDirectory)
        let loader = bundleLoader
        let settingsReplacements = Self.currentReplacements()

        let flagged = await Task.detached { () -> [TemplateDescriptor] in
            var baselines = Self.loadBaselines(url: baselinesFile)
            var flagged: [TemplateDescriptor] = []

            for template in resolved {
                guard let rawData = loader(template.bundleResource) else { continue }
                let bundleHash = Self.canonicalHash(rawData, template: rawData)
                let baseline = baselines[template.name]
                let userFileExists = FileManager.default.fileExists(atPath: template.userFileURL.path)

                let userData: Data? = userFileExists
                    ? try? Data(contentsOf: template.userFileURL)
                    : nil
                let userHash: String? = userData.map { Self.canonicalHash($0, template: rawData) }

                guard let baseline else {
                    if !userFileExists {
                        let dataToWrite = Self.applyReplacements(
                            rawData, replacements: settingsReplacements
                        )
                        Self.write(dataToWrite, to: template.userFileURL)
                        baselines[template.name] = bundleHash
                    } else if userHash == bundleHash {
                        baselines[template.name] = bundleHash
                    } else {
                        flagged.append(template)
                    }
                    continue
                }

                if baseline == bundleHash { continue }

                if !userFileExists || userHash == baseline {
                    let replacements = Self.extractedOrFallbackReplacements(
                        userData: userData, template: rawData, fallback: settingsReplacements
                    )
                    let dataToWrite = Self.applyReplacements(rawData, replacements: replacements)
                    Self.write(dataToWrite, to: template.userFileURL)
                    baselines[template.name] = bundleHash
                } else {
                    flagged.append(template)
                }
            }

            Self.saveBaselines(baselines, url: baselinesFile)
            return flagged
        }.value

        pendingTemplates = flagged
    }

    func applyBundled(for template: TemplateDescriptor, rootDirectory: URL) async {
        let baselinesFile = Self.baselinesURL(rootDirectory: rootDirectory)
        let loader = bundleLoader
        let settingsReplacements = Self.currentReplacements()

        await Task.detached {
            guard let rawData = loader(template.bundleResource) else { return }
            let userData = try? Data(contentsOf: template.userFileURL)
            let replacements = Self.extractedOrFallbackReplacements(
                userData: userData, template: rawData, fallback: settingsReplacements
            )
            let dataToWrite = Self.applyReplacements(rawData, replacements: replacements)
            Self.write(dataToWrite, to: template.userFileURL)
            var baselines = Self.loadBaselines(url: baselinesFile)
            baselines[template.name] = Self.canonicalHash(rawData, template: rawData)
            Self.saveBaselines(baselines, url: baselinesFile)
        }.value

        pendingTemplates.removeAll { $0.id == template.id }
    }

    func keepUser(for template: TemplateDescriptor, rootDirectory: URL) async {
        await commit(for: template, content: nil, rootDirectory: rootDirectory)
    }

    /// Commits a user's review of a template. Writes `content` to the user
    /// file when provided, then advances the baseline to the current bundled
    /// hash and removes the template from pending updates.
    ///
    /// Pass `nil` for `content` to only advance the baseline (keep file as-is).
    func commit(
        for template: TemplateDescriptor, content: String?, rootDirectory: URL
    ) async {
        let baselinesFile = Self.baselinesURL(rootDirectory: rootDirectory)
        let loader = bundleLoader

        await Task.detached {
            guard let rawData = loader(template.bundleResource) else { return }
            if let content {
                Self.write(Data(content.utf8), to: template.userFileURL)
            }
            var baselines = Self.loadBaselines(url: baselinesFile)
            baselines[template.name] = Self.canonicalHash(rawData, template: rawData)
            Self.saveBaselines(baselines, url: baselinesFile)
        }.value

        pendingTemplates.removeAll { $0.id == template.id }
    }

    func bundledData(for template: TemplateDescriptor) -> Data {
        bundleLoader(template.bundleResource) ?? Data()
    }

    func userData(for template: TemplateDescriptor) -> Data {
        (try? Data(contentsOf: template.userFileURL)) ?? Data()
    }

    // MARK: - Private helpers

    @Sendable
    nonisolated static func defaultBundleLoader(_ resource: String) -> Data? {
        guard let url = Bundle.main.url(
            forResource: resource, withExtension: "md", subdirectory: "Templates"
        ) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            IssueLogger.log(.warning, "Failed to read bundled template", context: resource, error: error)
            return nil
        }
    }

    nonisolated static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func currentReplacements() -> [String: String] {
        [
            "{{name}}": AppSettings.userName,
            "{{job}}": AppSettings.userJob,
        ]
    }

    nonisolated static func applyReplacements(
        _ data: Data, replacements: [String: String]
    ) -> Data {
        guard !replacements.isEmpty,
              let string = String(data: data, encoding: .utf8) else { return data }
        var result = string
        for (key, value) in replacements where !value.isEmpty {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return Data(result.utf8)
    }

    typealias TaggedLine = TemplatePlaceholderEngine.TaggedLine

    nonisolated static func taggedLines(of data: Data, template: Data) -> [TaggedLine] {
        TemplatePlaceholderEngine.taggedLines(of: data, template: template)
    }

    nonisolated static func canonicalHash(_ data: Data, template: Data) -> String {
        let canonical = taggedLines(of: data, template: template)
            .map(\.canonical)
            .joined(separator: "\n")
        return sha256(Data(canonical.utf8))
    }

    nonisolated static func extractedOrFallbackReplacements(
        userData: Data?, template: Data, fallback: [String: String]
    ) -> [String: String] {
        TemplatePlaceholderEngine.extractedOrFallbackReplacements(
            userData: userData, template: template, fallback: fallback
        )
    }

    nonisolated private static func loadBaselines(url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    nonisolated private static func saveBaselines(_ baselines: [String: String], url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(baselines)
            try data.write(to: url, options: .atomic)
        } catch {
            IssueLogger.log(.error, "Failed to save template baselines", context: url.path, error: error)
        }
    }

    nonisolated private static func write(_ data: Data, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            IssueLogger.log(.error, "Failed to write template", context: url.path, error: error)
        }
    }
}

import XCTest
@testable import Maurice

@MainActor
final class TemplateUpdateServiceTests: XCTestCase {

    private var tempDir: URL!
    private var bundleContent: [String: String] = [:]

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TemplateUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        bundleContent = [:]
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeService() -> TemplateUpdateService {
        let snapshot = bundleContent
        return TemplateUpdateService(bundleLoader: { resource in
            snapshot[resource].map { Data($0.utf8) }
        })
    }

    private func descriptor(name: String, resource: String) -> TemplateUpdateService.TemplateDescriptor {
        TemplateUpdateService.TemplateDescriptor(
            name: name,
            bundleResource: resource,
            userFileURL: tempDir.appendingPathComponent(name)
        )
    }

    private func readUserFile(_ template: TemplateUpdateService.TemplateDescriptor) -> String? {
        try? String(contentsOf: template.userFileURL, encoding: .utf8)
    }

    private func readBaselines() -> [String: String] {
        let url = TemplateUpdateService.baselinesURL(rootDirectory: tempDir)
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    // MARK: - First run seeding

    func testFirstRunCopiesMissingUserFileAndSeedsBaseline() async {
        bundleContent["foo"] = "hello"
        let service = makeService()
        let template = descriptor(name: "foo.md", resource: "foo")

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertEqual(readUserFile(template), "hello")
        XCTAssertFalse(service.hasPendingUpdates)
        let baselines = readBaselines()
        XCTAssertEqual(baselines["foo.md"], TemplateUpdateService.canonicalHash(Data("hello".utf8), template: Data("hello".utf8)))
    }

    func testFirstRunFlagsDivergentUserFileWithoutSeedingBaseline() async {
        bundleContent["foo"] = "bundled"
        let template = descriptor(name: "foo.md", resource: "foo")
        try? "my custom content".write(to: template.userFileURL, atomically: true, encoding: .utf8)
        let service = makeService()

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertEqual(readUserFile(template), "my custom content")
        XCTAssertTrue(service.hasPendingUpdates)
        XCTAssertEqual(service.pendingTemplates.first?.name, "foo.md")
        // Baseline must NOT be set so the flag persists until the user resolves it
        XCTAssertNil(readBaselines()["foo.md"])
    }

    func testFirstRunSeedsBaselineWhenUserFileMatchesBundle() async {
        bundleContent["foo"] = "bundled"
        let template = descriptor(name: "foo.md", resource: "foo")
        try? "bundled".write(to: template.userFileURL, atomically: true, encoding: .utf8)
        let service = makeService()

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertFalse(service.hasPendingUpdates)
        XCTAssertEqual(
            readBaselines()["foo.md"],
            TemplateUpdateService.canonicalHash(Data("bundled".utf8), template: Data("bundled".utf8))
        )
    }

    // MARK: - Up to date

    func testUpToDateIsNoOp() async {
        bundleContent["foo"] = "same"
        let template = descriptor(name: "foo.md", resource: "foo")
        let service = makeService()

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])
        // Second run should not change anything
        try? "user edited".write(to: template.userFileURL, atomically: true, encoding: .utf8)
        await service.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertEqual(readUserFile(template), "user edited")
        XCTAssertFalse(service.hasPendingUpdates)
    }

    // MARK: - Silent update

    func testSilentUpdateWhenUserNeverTouched() async {
        bundleContent["foo"] = "v1"
        let template = descriptor(name: "foo.md", resource: "foo")
        let service = makeService()

        // First seed
        await service.reconcile(rootDirectory: tempDir, descriptors: [template])
        XCTAssertEqual(readUserFile(template), "v1")

        // New bundled version, user file still equals v1 → silent overwrite
        bundleContent["foo"] = "v2"
        let service2 = makeService()
        await service2.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertEqual(readUserFile(template), "v2")
        XCTAssertFalse(service2.hasPendingUpdates)
        XCTAssertEqual(readBaselines()["foo.md"], TemplateUpdateService.canonicalHash(Data("v2".utf8), template: Data("v2".utf8)))
    }

    // MARK: - Flagged when customized

    func testFlaggedWhenUserCustomizedAndBundleChanged() async {
        bundleContent["foo"] = "v1"
        let template = descriptor(name: "foo.md", resource: "foo")
        let service = makeService()

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])
        // User customizes
        try? "user custom".write(to: template.userFileURL, atomically: true, encoding: .utf8)

        // New bundled version
        bundleContent["foo"] = "v2"
        let service2 = makeService()
        await service2.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertEqual(readUserFile(template), "user custom")
        XCTAssertTrue(service2.hasPendingUpdates)
        XCTAssertEqual(service2.pendingTemplates.first?.name, "foo.md")
        // Baseline not advanced yet (still v1)
        XCTAssertEqual(readBaselines()["foo.md"], TemplateUpdateService.canonicalHash(Data("v1".utf8), template: Data("v1".utf8)))
    }

    // MARK: - Apply / Keep

    func testApplyBundledOverwritesUserFileAndAdvancesBaseline() async {
        bundleContent["foo"] = "v1"
        let template = descriptor(name: "foo.md", resource: "foo")
        let service = makeService()

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])
        try? "user custom".write(to: template.userFileURL, atomically: true, encoding: .utf8)

        bundleContent["foo"] = "v2"
        let service2 = makeService()
        await service2.reconcile(rootDirectory: tempDir, descriptors: [template])
        XCTAssertTrue(service2.hasPendingUpdates)

        await service2.applyBundled(for: template, rootDirectory: tempDir)

        XCTAssertEqual(readUserFile(template), "v2")
        XCTAssertFalse(service2.hasPendingUpdates)
        XCTAssertEqual(readBaselines()["foo.md"], TemplateUpdateService.canonicalHash(Data("v2".utf8), template: Data("v2".utf8)))
    }

    func testKeepUserLeavesFileAndAdvancesBaseline() async {
        bundleContent["foo"] = "v1"
        let template = descriptor(name: "foo.md", resource: "foo")
        let service = makeService()

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])
        try? "user custom".write(to: template.userFileURL, atomically: true, encoding: .utf8)

        bundleContent["foo"] = "v2"
        let service2 = makeService()
        await service2.reconcile(rootDirectory: tempDir, descriptors: [template])
        XCTAssertTrue(service2.hasPendingUpdates)

        await service2.keepUser(for: template, rootDirectory: tempDir)

        XCTAssertEqual(readUserFile(template), "user custom")
        XCTAssertFalse(service2.hasPendingUpdates)
        XCTAssertEqual(readBaselines()["foo.md"], TemplateUpdateService.canonicalHash(Data("v2".utf8), template: Data("v2".utf8)))
    }

    // MARK: - Replacement substitution

    func testApplyReplacementsSubstitutesKnownKeys() {
        let data = Data("Hello {{name}}, role {{job}}".utf8)
        let resolved = TemplateUpdateService.applyReplacements(
            data,
            replacements: ["{{name}}": "Alice", "{{job}}": "Eng"]
        )
        XCTAssertEqual(String(data: resolved, encoding: .utf8), "Hello Alice, role Eng")
    }

    func testApplyReplacementsSkipsEmptyValues() {
        let data = Data("Hello {{name}}".utf8)
        let resolved = TemplateUpdateService.applyReplacements(
            data,
            replacements: ["{{name}}": ""]
        )
        XCTAssertEqual(String(data: resolved, encoding: .utf8), "Hello {{name}}")
    }

    // MARK: - Placeholder-aware comparison

    func testUserFileWithSubstitutedValuesIsEquivalentToBundledTemplate() async {
        bundleContent["foo"] = "Hello {{name}}\nBody unchanged"
        let template = descriptor(name: "foo.md", resource: "foo")
        try? "Hello Alice\nBody unchanged"
            .write(to: template.userFileURL, atomically: true, encoding: .utf8)
        let service = makeService()

        await service.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertFalse(
            service.hasPendingUpdates,
            "User file with substituted placeholders should be treated as up-to-date"
        )
        XCTAssertNotNil(readBaselines()["foo.md"])
    }

    func testDiffFlagsOnlyNonPlaceholderChanges() async {
        bundleContent["foo"] = "Hello {{name}}\nOld body"
        let template = descriptor(name: "foo.md", resource: "foo")
        try? "Hello Alice\nOld body"
            .write(to: template.userFileURL, atomically: true, encoding: .utf8)
        let service = makeService()
        await service.reconcile(rootDirectory: tempDir, descriptors: [template])

        // New bundled changes the non-placeholder body
        bundleContent["foo"] = "Hello {{name}}\nNew body"
        let service2 = makeService()
        await service2.reconcile(rootDirectory: tempDir, descriptors: [template])

        XCTAssertTrue(service2.hasPendingUpdates)
    }

    func testExtractedReplacementsRecoverPlaceholderValuesFromUserFile() {
        let template = Data("Tu es {{name}}, {{job}}.\nAutre ligne".utf8)
        let user = Data("Tu es Maxime, PM.\nAutre ligne".utf8)
        let extracted = TemplateUpdateService.extractedOrFallbackReplacements(
            userData: user, template: template, fallback: [:]
        )
        XCTAssertEqual(extracted["{{name}}"], "Maxime")
        XCTAssertEqual(extracted["{{job}}"], "PM")
    }

    // MARK: - commit (decision workflow)

    func testCommitWithContentWritesFileAndAdvancesBaseline() async {
        bundleContent["foo"] = "v1"
        let template = descriptor(name: "foo.md", resource: "foo")
        let service = makeService()
        await service.reconcile(rootDirectory: tempDir, descriptors: [template])
        try? "user custom".write(to: template.userFileURL, atomically: true, encoding: .utf8)

        bundleContent["foo"] = "v2"
        let service2 = makeService()
        await service2.reconcile(rootDirectory: tempDir, descriptors: [template])
        XCTAssertTrue(service2.hasPendingUpdates)

        await service2.commit(for: template, content: "merged", rootDirectory: tempDir)

        XCTAssertEqual(readUserFile(template), "merged")
        XCTAssertFalse(service2.hasPendingUpdates)
        XCTAssertEqual(
            readBaselines()["foo.md"],
            TemplateUpdateService.canonicalHash(Data("v2".utf8), template: Data("v2".utf8))
        )
    }

    func testCommitWithNilContentAdvancesBaselineWithoutWriting() async {
        bundleContent["foo"] = "v1"
        let template = descriptor(name: "foo.md", resource: "foo")
        let service = makeService()
        await service.reconcile(rootDirectory: tempDir, descriptors: [template])
        try? "user custom".write(to: template.userFileURL, atomically: true, encoding: .utf8)

        bundleContent["foo"] = "v2"
        let service2 = makeService()
        await service2.reconcile(rootDirectory: tempDir, descriptors: [template])

        await service2.commit(for: template, content: nil, rootDirectory: tempDir)

        XCTAssertEqual(readUserFile(template), "user custom")
        XCTAssertFalse(service2.hasPendingUpdates)
        XCTAssertEqual(
            readBaselines()["foo.md"],
            TemplateUpdateService.canonicalHash(Data("v2".utf8), template: Data("v2".utf8))
        )
    }

    // MARK: - Tagged lines

    func testTaggedLinesCanonicalEqualsBetweenBundledAndUserSubstituted() {
        let bundled = Data("Hi {{name}}!\nBody".utf8)
        let user = Data("Hi Alice!\nBody".utf8)
        let bundledTagged = TemplateUpdateService.taggedLines(of: bundled, template: bundled)
        let userTagged = TemplateUpdateService.taggedLines(of: user, template: bundled)

        XCTAssertEqual(bundledTagged[0].canonical, userTagged[0].canonical)
        XCTAssertEqual(bundledTagged[0].display, "Hi {{name}}!")
        XCTAssertEqual(userTagged[0].display, "Hi Alice!")
        XCTAssertEqual(bundledTagged[1], userTagged[1])
    }

    func testCanonicalHashInvariantToPlaceholderSubstitution() {
        let bundled = Data("Hi {{name}}\nShared".utf8)
        let user = Data("Hi Alice\nShared".utf8)
        XCTAssertEqual(
            TemplateUpdateService.canonicalHash(bundled, template: bundled),
            TemplateUpdateService.canonicalHash(user, template: bundled)
        )
    }

    func testCanonicalHashDiffersOnNonPlaceholderChange() {
        let bundled = Data("Hi {{name}}\nOld body".utf8)
        let user = Data("Hi Alice\nNew body".utf8)
        XCTAssertNotEqual(
            TemplateUpdateService.canonicalHash(bundled, template: bundled),
            TemplateUpdateService.canonicalHash(user, template: bundled)
        )
    }
}

import XCTest
@testable import Maurice

final class MeetingConfigTests: XCTestCase {

    // MARK: - Default Init

    func testDefaultInitContainsDefaultActions() {
        let config = MeetingConfig()

        XCTAssertNil(config.icon)
        XCTAssertNil(config.calendarEventName)
        XCTAssertEqual(config.actions.count, 1)
    }

    func testDefaultActionsContainsResumeMeetingSkill() {
        let config = MeetingConfig()

        let resumeAction = config.actions.first
        XCTAssertNotNil(resumeAction)
        XCTAssertEqual(resumeAction?.buttonName, "Résumé")
        XCTAssertEqual(resumeAction?.skillFilename, "resume-meeting.md")
    }

    func testStaticDefaultActionsMatchDefaultInit() {
        let staticActions = MeetingConfig.defaultActions
        let config = MeetingConfig()

        XCTAssertEqual(staticActions.count, config.actions.count)
        XCTAssertEqual(staticActions.first?.buttonName, config.actions.first?.buttonName)
        XCTAssertEqual(staticActions.first?.skillFilename, config.actions.first?.skillFilename)
    }

    func testCustomInit() {
        let action = SkillAction(buttonName: "Test", skillFilename: "test.md")
        let config = MeetingConfig(icon: "star", calendarEventName: "Daily", actions: [action])

        XCTAssertEqual(config.icon, "star")
        XCTAssertEqual(config.calendarEventName, "Daily")
        XCTAssertEqual(config.actions.count, 1)
        XCTAssertEqual(config.actions.first?.buttonName, "Test")
    }

    func testCustomInitWithEmptyActions() {
        let config = MeetingConfig(icon: nil, calendarEventName: nil, actions: [])

        XCTAssertTrue(config.actions.isEmpty)
    }

    // MARK: - addAction

    func testAddActionAppendsToList() {
        var config = MeetingConfig()
        let initialCount = config.actions.count

        let newAction = SkillAction(buttonName: "Notes", skillFilename: "notes.md")
        config.addAction(newAction)

        XCTAssertEqual(config.actions.count, initialCount + 1)
        XCTAssertEqual(config.actions.last?.buttonName, "Notes")
        XCTAssertEqual(config.actions.last?.skillFilename, "notes.md")
    }

    func testAddMultipleActions() {
        var config = MeetingConfig(actions: [])

        config.addAction(SkillAction(buttonName: "A", skillFilename: "a.md"))
        config.addAction(SkillAction(buttonName: "B", skillFilename: "b.md"))
        config.addAction(SkillAction(buttonName: "C", skillFilename: "c.md"))

        XCTAssertEqual(config.actions.count, 3)
        XCTAssertEqual(config.actions.map(\.buttonName), ["A", "B", "C"])
    }

    // MARK: - removeAction

    func testRemoveActionById() {
        let action1 = SkillAction(buttonName: "Keep", skillFilename: "keep.md")
        let action2 = SkillAction(buttonName: "Remove", skillFilename: "remove.md")
        var config = MeetingConfig(actions: [action1, action2])

        config.removeAction(id: action2.id)

        XCTAssertEqual(config.actions.count, 1)
        XCTAssertEqual(config.actions.first?.buttonName, "Keep")
    }

    func testRemoveActionWithNonExistentIdDoesNothing() {
        var config = MeetingConfig()
        let initialCount = config.actions.count

        config.removeAction(id: UUID())

        XCTAssertEqual(config.actions.count, initialCount)
    }

    func testRemoveAllActions() {
        let action = SkillAction(buttonName: "Only", skillFilename: "only.md")
        var config = MeetingConfig(actions: [action])

        config.removeAction(id: action.id)

        XCTAssertTrue(config.actions.isEmpty)
    }

    // MARK: - updateAction

    func testUpdateActionChangesFields() {
        let action = SkillAction(buttonName: "Old", skillFilename: "old.md")
        var config = MeetingConfig(actions: [action])

        config.updateAction(id: action.id, buttonName: "New", skillFilename: "new.md", parameter: "param1")

        XCTAssertEqual(config.actions.count, 1)
        XCTAssertEqual(config.actions.first?.id, action.id)
        XCTAssertEqual(config.actions.first?.buttonName, "New")
        XCTAssertEqual(config.actions.first?.skillFilename, "new.md")
        XCTAssertEqual(config.actions.first?.parameter, "param1")
    }

    func testUpdateActionWithNonExistentIdDoesNothing() {
        let action = SkillAction(buttonName: "Original", skillFilename: "original.md")
        var config = MeetingConfig(actions: [action])

        config.updateAction(id: UUID(), buttonName: "Changed", skillFilename: "changed.md")

        XCTAssertEqual(config.actions.first?.buttonName, "Original")
    }

    func testUpdateActionPreservesOtherActions() {
        let action1 = SkillAction(buttonName: "First", skillFilename: "first.md")
        let action2 = SkillAction(buttonName: "Second", skillFilename: "second.md")
        var config = MeetingConfig(actions: [action1, action2])

        config.updateAction(id: action2.id, buttonName: "Updated", skillFilename: "updated.md")

        XCTAssertEqual(config.actions[0].buttonName, "First")
        XCTAssertEqual(config.actions[1].buttonName, "Updated")
    }

    func testUpdateActionWithNilParameter() {
        let action = SkillAction(buttonName: "Act", skillFilename: "act.md", parameter: "existing")
        var config = MeetingConfig(actions: [action])

        config.updateAction(id: action.id, buttonName: "Act", skillFilename: "act.md")

        XCTAssertNil(config.actions.first?.parameter)
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtripDefaultConfig() throws {
        let original = MeetingConfig()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MeetingConfig.self, from: data)

        XCTAssertEqual(decoded.icon, original.icon)
        XCTAssertEqual(decoded.calendarEventName, original.calendarEventName)
        XCTAssertEqual(decoded.actions.count, original.actions.count)
        XCTAssertEqual(decoded.actions.first?.buttonName, original.actions.first?.buttonName)
        XCTAssertEqual(decoded.actions.first?.skillFilename, original.actions.first?.skillFilename)
    }

    func testCodableRoundtripCustomConfig() throws {
        let action = SkillAction(buttonName: "Encode", skillFilename: "encode.md", parameter: "p1")
        let original = MeetingConfig(icon: "rocket", calendarEventName: "Sprint Review", actions: [action])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MeetingConfig.self, from: data)

        XCTAssertEqual(decoded.icon, "rocket")
        XCTAssertEqual(decoded.calendarEventName, "Sprint Review")
        XCTAssertEqual(decoded.actions.count, 1)
        XCTAssertEqual(decoded.actions.first?.buttonName, "Encode")
        XCTAssertEqual(decoded.actions.first?.skillFilename, "encode.md")
        XCTAssertEqual(decoded.actions.first?.parameter, "p1")
    }

    func testCodableRoundtripPreservesActionIds() throws {
        let action = SkillAction(buttonName: "ID Test", skillFilename: "id.md")
        let original = MeetingConfig(actions: [action])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MeetingConfig.self, from: data)

        XCTAssertEqual(decoded.actions.first?.id, action.id)
    }

    func testCodableRoundtripEmptyActions() throws {
        let original = MeetingConfig(actions: [])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MeetingConfig.self, from: data)

        XCTAssertTrue(decoded.actions.isEmpty)
    }

    func testCodableRoundtripMultipleActions() throws {
        let actions = [
            SkillAction(buttonName: "A", skillFilename: "a.md"),
            SkillAction(buttonName: "B", skillFilename: "b.md", parameter: "x"),
            SkillAction(buttonName: "C", skillFilename: "c.md")
        ]
        let original = MeetingConfig(icon: "meeting", actions: actions)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MeetingConfig.self, from: data)

        XCTAssertEqual(decoded.actions.count, 3)
        XCTAssertEqual(decoded.actions.map(\.buttonName), ["A", "B", "C"])
        XCTAssertEqual(decoded.actions[1].parameter, "x")
        XCTAssertNil(decoded.actions[0].parameter)
    }
}

// MARK: - SkillFile Tests

final class SkillFileTests: XCTestCase {

    // MARK: - Name Formatting

    func testNameRemovesMdExtension() {
        let file = SkillFile(filename: "resume-meeting.md")
        XCTAssertEqual(file.name, "Resume Meeting")
    }

    func testNameReplacesHyphensWithSpaces() {
        let file = SkillFile(filename: "take-notes.md")
        XCTAssertEqual(file.name, "Take Notes")
    }

    func testNameCapitalizesWords() {
        let file = SkillFile(filename: "generate-action-items.md")
        XCTAssertEqual(file.name, "Generate Action Items")
    }

    func testNameHandlesSingleWord() {
        let file = SkillFile(filename: "summary.md")
        XCTAssertEqual(file.name, "Summary")
    }

    // MARK: - SkillFile URL

    func testUrlUsesClaudeCommandsDirectory() {
        let file = SkillFile(filename: "test-skill.md")

        let expectedURL = AppSettings.claudeCommandsDirectory.appendingPathComponent("test-skill.md")
        XCTAssertEqual(file.url, expectedURL)
    }

    // MARK: - SkillFile Identity

    func testIdMatchesFilename() {
        let file = SkillFile(filename: "my-skill.md")
        XCTAssertEqual(file.id, "my-skill.md")
    }

    func testHashableEquality() {
        let file1 = SkillFile(filename: "same.md")
        let file2 = SkillFile(filename: "same.md")
        XCTAssertEqual(file1, file2)
    }

    func testHashableInequality() {
        let file1 = SkillFile(filename: "one.md")
        let file2 = SkillFile(filename: "two.md")
        XCTAssertNotEqual(file1, file2)
    }

    // MARK: - SkillFile Codable

    func testSkillFileCodableRoundtrip() throws {
        let original = SkillFile(filename: "test-skill.md")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkillFile.self, from: data)

        XCTAssertEqual(decoded.filename, original.filename)
        XCTAssertEqual(decoded.id, original.id)
    }
}

// MARK: - SkillAction Tests

final class SkillActionTests: XCTestCase {

    func testInitWithDefaults() {
        let action = SkillAction(buttonName: "Test", skillFilename: "test.md")

        XCTAssertFalse(action.id.uuidString.isEmpty)
        XCTAssertEqual(action.buttonName, "Test")
        XCTAssertEqual(action.skillFilename, "test.md")
        XCTAssertNil(action.parameter)
    }

    func testInitWithParameter() {
        let action = SkillAction(buttonName: "Act", skillFilename: "act.md", parameter: "value")

        XCTAssertEqual(action.parameter, "value")
    }

    func testInitWithExplicitId() {
        let id = UUID()
        let action = SkillAction(id: id, buttonName: "Custom", skillFilename: "custom.md")

        XCTAssertEqual(action.id, id)
    }

    func testCodableRoundtrip() throws {
        let original = SkillAction(buttonName: "Encode", skillFilename: "encode.md", parameter: "p")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkillAction.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.buttonName, original.buttonName)
        XCTAssertEqual(decoded.skillFilename, original.skillFilename)
        XCTAssertEqual(decoded.parameter, original.parameter)
    }

    func testCodableRoundtripWithNilParameter() throws {
        let original = SkillAction(buttonName: "NoParam", skillFilename: "noparam.md")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkillAction.self, from: data)

        XCTAssertNil(decoded.parameter)
    }

    func testHashableEquality() {
        let id = UUID()
        let action1 = SkillAction(id: id, buttonName: "Same", skillFilename: "same.md")
        let action2 = SkillAction(id: id, buttonName: "Same", skillFilename: "same.md")
        XCTAssertEqual(action1, action2)
    }

    func testHashableInequalityByName() {
        let id = UUID()
        let action1 = SkillAction(id: id, buttonName: "A", skillFilename: "a.md")
        let action2 = SkillAction(id: id, buttonName: "B", skillFilename: "a.md")
        XCTAssertNotEqual(action1, action2)
    }
}

import XCTest
import SwiftUI
@testable import Maurice

@MainActor
final class AppKitMenuButtonTests: XCTestCase {

    // MARK: - Coordinator.makeMenu

    func testMakeMenuItemCountMatchesEntries() {
        let entries: [AppKitMenuEntry] = [
            .item(title: "A", action: { }),
            .separator,
            .item(title: "B", action: { })
        ]
        let menu = makeMenu(from: entries)
        XCTAssertEqual(menu.items.count, 3)
    }

    func testMakeMenuSeparatorRendersAsSeparator() {
        let entries: [AppKitMenuEntry] = [
            .item(title: "A", action: { }),
            .separator,
            .item(title: "B", action: { })
        ]
        let menu = makeMenu(from: entries)
        XCTAssertFalse(menu.items[0].isSeparatorItem)
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertFalse(menu.items[2].isSeparatorItem)
    }

    func testMakeMenuItemTitlesMatch() {
        let entries: [AppKitMenuEntry] = [
            .item(title: "Hello", action: { }),
            .item(title: "World", action: { })
        ]
        let menu = makeMenu(from: entries)
        XCTAssertEqual(menu.items[0].title, "Hello")
        XCTAssertEqual(menu.items[1].title, "World")
    }

    func testMakeMenuDestructiveItemHasRedAttributedTitle() {
        let entries: [AppKitMenuEntry] = [
            .item(title: "Delete", isDestructive: true, action: { })
        ]
        let menu = makeMenu(from: entries)
        guard let attributed = menu.items[0].attributedTitle else {
            XCTFail("Destructive item should have an attributedTitle")
            return
        }
        let attrs = attributed.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attrs[.foregroundColor] as? NSColor, NSColor.systemRed)
    }

    func testMakeMenuPlainItemHasNoAttributedTitle() {
        let entries: [AppKitMenuEntry] = [
            .item(title: "Plain", action: { })
        ]
        let menu = makeMenu(from: entries)
        XCTAssertNil(menu.items[0].attributedTitle)
    }

    func testMakeMenuItemWithSystemImageHasImage() {
        let entries: [AppKitMenuEntry] = [
            .item(title: "Trash", systemImage: "trash", action: { })
        ]
        let menu = makeMenu(from: entries)
        XCTAssertNotNil(menu.items[0].image)
    }

    func testMakeMenuItemWithoutSystemImageHasNoImage() {
        let entries: [AppKitMenuEntry] = [
            .item(title: "Plain", action: { })
        ]
        let menu = makeMenu(from: entries)
        XCTAssertNil(menu.items[0].image)
    }

    func testMakeMenuTagDispatchInvokesCorrectAction() {
        var aCalled = 0
        var bCalled = 0
        let entries: [AppKitMenuEntry] = [
            .item(title: "A", action: { aCalled += 1 }),
            .separator,
            .item(title: "B", action: { bCalled += 1 })
        ]

        let coordinator = makeCoordinator(entries: entries)
        let menu = coordinator.makeMenu()

        // Item B has tag = 2 (entries index), separator at tag-less index 1.
        guard let itemB = menu.items.first(where: { $0.tag == 2 }) else {
            XCTFail("Expected NSMenuItem with tag 2")
            return
        }
        guard let target = itemB.target as? NSObject, let action = itemB.action else {
            XCTFail("Item missing target or action")
            return
        }
        target.perform(action, with: itemB)

        XCTAssertEqual(aCalled, 0)
        XCTAssertEqual(bCalled, 1)
    }

    // MARK: - SkillsPillMenu.makeEntries

    func testSkillsPillMenuNoActionsNoConfigure() {
        let entries = SkillsPillMenu.makeEntries(
            actions: [], runAction: { _ in }, onConfigure: nil
        )
        XCTAssertTrue(entries.isEmpty)
    }

    func testSkillsPillMenuOnlyConfigureHasNoLeadingSeparator() {
        let entries = SkillsPillMenu.makeEntries(
            actions: [], runAction: { _ in }, onConfigure: { }
        )
        XCTAssertEqual(entries.count, 1)
        guard case .item(let title, let systemImage, let isDestructive, _) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        XCTAssertEqual(title, String(localized: "Edit skills for this meeting"))
        XCTAssertEqual(systemImage, "slider.horizontal.3")
        XCTAssertFalse(isDestructive)
    }

    func testSkillsPillMenuActionsOnly() {
        let action = SkillAction(buttonName: "Préparer", skillFilename: "prep.md")
        let entries = SkillsPillMenu.makeEntries(
            actions: [action], runAction: { _ in }, onConfigure: nil
        )
        XCTAssertEqual(entries.count, 1)
        guard case .item(let title, _, _, _) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        XCTAssertEqual(title, "Préparer")
    }

    func testSkillsPillMenuActionWithParameterIncludesParameterInTitle() {
        let action = SkillAction(
            buttonName: "Format", skillFilename: "format.md", parameter: "compact"
        )
        let entries = SkillsPillMenu.makeEntries(
            actions: [action], runAction: { _ in }, onConfigure: nil
        )
        guard case .item(let title, _, _, _) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        XCTAssertEqual(title, "Format — compact")
    }

    func testSkillsPillMenuActionWithEmptyParameterUsesButtonName() {
        let action = SkillAction(
            buttonName: "Plain", skillFilename: "plain.md", parameter: ""
        )
        let entries = SkillsPillMenu.makeEntries(
            actions: [action], runAction: { _ in }, onConfigure: nil
        )
        guard case .item(let title, _, _, _) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        XCTAssertEqual(title, "Plain")
    }

    func testSkillsPillMenuActionsThenSeparatorThenConfigure() {
        let action = SkillAction(buttonName: "A", skillFilename: "a.md")
        let entries = SkillsPillMenu.makeEntries(
            actions: [action], runAction: { _ in }, onConfigure: { }
        )
        XCTAssertEqual(entries.count, 3)

        guard case .item = entries[0] else {
            XCTFail("Expected item at 0")
            return
        }
        guard case .separator = entries[1] else {
            XCTFail("Expected separator at 1")
            return
        }
        guard case .item(let title, _, _, _) = entries[2] else {
            XCTFail("Expected item at 2")
            return
        }
        XCTAssertEqual(title, String(localized: "Edit skills for this meeting"))
    }

    func testSkillsPillMenuRunActionInvokedWithMatchingSkillAction() {
        let action = SkillAction(buttonName: "X", skillFilename: "x.md")
        var received: SkillAction?
        let entries = SkillsPillMenu.makeEntries(
            actions: [action], runAction: { received = $0 }, onConfigure: nil
        )
        guard case .item(_, _, _, let invoke) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        invoke()
        XCTAssertEqual(received, action)
    }

    func testSkillsPillMenuConfigureCallbackInvoked() {
        var configureCalled = 0
        let entries = SkillsPillMenu.makeEntries(
            actions: [], runAction: { _ in }, onConfigure: { configureCalled += 1 }
        )
        guard case .item(_, _, _, let invoke) = entries[0] else {
            XCTFail("Expected configure item")
            return
        }
        invoke()
        XCTAssertEqual(configureCalled, 1)
    }

    // MARK: - EntryMoreMenu.makeEntries

    func testEntryMoreMenuEmptyEntryProducesNoEntries() {
        let entry = makeEntry(hasNote: false, hasTranscript: false)
        let entries = EntryMoreMenu.makeEntries(entry: entry, delete: { _ in })
        XCTAssertTrue(entries.isEmpty)
    }

    func testEntryMoreMenuNoteOnly() {
        let entry = makeEntry(hasNote: true, hasTranscript: false)
        let entries = EntryMoreMenu.makeEntries(entry: entry, delete: { _ in })
        XCTAssertEqual(entries.count, 1)
        guard case .item(let title, let systemImage, let isDestructive, _) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        XCTAssertEqual(title, String(localized: "Delete note"))
        XCTAssertEqual(systemImage, "doc.text")
        XCTAssertTrue(isDestructive)
    }

    func testEntryMoreMenuTranscriptOnly() {
        let entry = makeEntry(hasNote: false, hasTranscript: true)
        let entries = EntryMoreMenu.makeEntries(entry: entry, delete: { _ in })
        XCTAssertEqual(entries.count, 1)
        guard case .item(let title, let systemImage, let isDestructive, _) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        XCTAssertEqual(title, String(localized: "Delete transcript"))
        XCTAssertEqual(systemImage, "waveform")
        XCTAssertTrue(isDestructive)
    }

    func testEntryMoreMenuBothShowsSeparatorAndAll() {
        let entry = makeEntry(hasNote: true, hasTranscript: true)
        let entries = EntryMoreMenu.makeEntries(entry: entry, delete: { _ in })
        XCTAssertEqual(entries.count, 4)

        guard case .item(let t0, let i0, let d0, _) = entries[0] else {
            XCTFail("Expected note item at 0")
            return
        }
        XCTAssertEqual(t0, String(localized: "Delete note"))
        XCTAssertEqual(i0, "doc.text")
        XCTAssertTrue(d0)

        guard case .item(let t1, let i1, let d1, _) = entries[1] else {
            XCTFail("Expected transcript item at 1")
            return
        }
        XCTAssertEqual(t1, String(localized: "Delete transcript"))
        XCTAssertEqual(i1, "waveform")
        XCTAssertTrue(d1)

        guard case .separator = entries[2] else {
            XCTFail("Expected separator at 2")
            return
        }

        guard case .item(let t3, let i3, let d3, _) = entries[3] else {
            XCTFail("Expected delete-all item at 3")
            return
        }
        XCTAssertEqual(t3, String(localized: "Delete all"))
        XCTAssertEqual(i3, "trash")
        XCTAssertTrue(d3)
    }

    func testEntryMoreMenuDeleteNoteActionInvokesNoteCase() {
        let entry = makeEntry(hasNote: true, hasTranscript: false)
        var received: EntryDeleteAction?
        let entries = EntryMoreMenu.makeEntries(entry: entry, delete: { received = $0 })
        guard case .item(_, _, _, let invoke) = entries[0] else {
            XCTFail("Expected item")
            return
        }
        invoke()
        if case .note(let e) = received {
            XCTAssertEqual(e.dateString, entry.dateString)
        } else {
            XCTFail("Expected .note action")
        }
    }

    func testEntryMoreMenuDeleteAllActionInvokesBothCase() {
        let entry = makeEntry(hasNote: true, hasTranscript: true)
        var received: EntryDeleteAction?
        let entries = EntryMoreMenu.makeEntries(entry: entry, delete: { received = $0 })
        guard case .item(_, _, _, let invoke) = entries[3] else {
            XCTFail("Expected delete-all item at 3")
            return
        }
        invoke()
        if case .both(let e) = received {
            XCTAssertEqual(e.dateString, entry.dateString)
        } else {
            XCTFail("Expected .both action")
        }
    }

    // MARK: - Helpers

    private func makeEntry(
        hasNote: Bool,
        hasTranscript: Bool,
        dateString: String = "2026-04-30"
    ) -> MeetingDateEntry {
        let url = URL(fileURLWithPath: "/tmp/test")
        let noteFile = hasNote
            ? FolderFile(id: url, name: "n", date: Date(), url: url)
            : nil
        let transcriptFile = hasTranscript
            ? FolderFile(id: url, name: "t", date: Date(), url: url)
            : nil
        return MeetingDateEntry(
            dateString: dateString,
            date: Date(),
            noteFile: noteFile,
            transcriptFile: transcriptFile
        )
    }

    private func makeMenu(from entries: [AppKitMenuEntry]) -> NSMenu {
        makeCoordinator(entries: entries).makeMenu()
    }

    private func makeCoordinator(
        entries: [AppKitMenuEntry]
    ) -> AppKitMenuButton.Coordinator {
        let button = AppKitMenuButton(entries: entries) {
            Color.clear.frame(width: 10, height: 10)
        }
        return AppKitMenuButton.Coordinator(parent: button)
    }
}

import XCTest
@testable import Maurice

final class FolderItemTests: XCTestCase {

    // MARK: - FolderItem

    func testIdUsesRelativePathWhenPresent() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem(name: "Test", url: url, files: [], relativePath: "Category/Test")
        XCTAssertEqual(item.id, "Category/Test")
    }

    func testIdUsesNameWhenNoRelativePath() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let item = FolderItem(name: "Test", url: url, files: [])
        XCTAssertEqual(item.id, "Test")
    }

    func testFileCountFromFiles() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let fileURL = URL(fileURLWithPath: "/tmp/test/a.md")
        let file = FolderFile(id: fileURL, name: "a", date: Date(), url: fileURL)
        let item = FolderItem(name: "Test", url: url, files: [file])
        XCTAssertEqual(item.fileCount, 1)
    }

    func testFileCountFromDateEntries() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let entry = MeetingDateEntry(dateString: "2026-03-27", date: Date(), noteFile: nil, transcript: nil)
        var item = FolderItem(name: "Test", url: url, files: [])
        item.dateEntries = [entry, entry]
        XCTAssertEqual(item.fileCount, 2)
    }

    func testFileCountUsesMaxOfFilesAndDateEntries() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let fileURL = URL(fileURLWithPath: "/tmp/test/a.md")
        let file = FolderFile(id: fileURL, name: "a", date: Date(), url: fileURL)
        let entry = MeetingDateEntry(dateString: "2026-03-27", date: Date(), noteFile: nil, transcript: nil)
        var item = FolderItem(name: "Test", url: url, files: [file])
        item.dateEntries = [entry, entry, entry]
        XCTAssertEqual(item.fileCount, 3)
    }

    // MARK: - PeopleCategory

    func testPeopleCategoryId() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let person = FolderItem(name: "Alice", url: url, files: [])
        let category = PeopleCategory(name: "Engineering", people: [person])
        XCTAssertEqual(category.id, "Engineering")
        XCTAssertEqual(category.people.count, 1)
    }

    // MARK: - Folder Entity

    func testFolderIdentity() {
        let url = URL(fileURLWithPath: "/tmp/meetings/standup")
        let folder = Folder(url: url)
        XCTAssertEqual(folder.id, url)
        XCTAssertEqual(folder.name, "standup")
    }

    func testFolderHashable() {
        let url1 = URL(fileURLWithPath: "/tmp/a")
        let url2 = URL(fileURLWithPath: "/tmp/b")
        let set: Set<Folder> = [Folder(url: url1), Folder(url: url2), Folder(url: url1)]
        XCTAssertEqual(set.count, 2)
    }
}

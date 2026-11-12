import XCTest
@testable import Notatka

final class ChangeHistoryTests: XCTestCase {
    private let earlier = Date(timeIntervalSinceReferenceDate: 1_000)
    private let now = Date(timeIntervalSinceReferenceDate: 2_000)

    func testAddedAndEditedItemsAreStamped() {
        let kept = TaskItem(title: "Kept")
        var edited = TaskItem(title: "Before")
        let category = TaskCategory(name: "Trip", colorHex: "#000000")
        var previous = LibrarySnapshot(tasks: [edited, kept], categories: [])
        previous.history.modifiedAt = [kept.id: earlier, edited.id: earlier]

        edited.title = "After"
        let added = TaskItem(title: "New")
        let recorded = LibrarySnapshot(tasks: [added, edited, kept], categories: [category])
            .recordingChanges(since: previous, at: now)

        XCTAssertEqual(recorded.history.modifiedAt, [kept.id: earlier, edited.id: now, added.id: now, category.id: now])
        XCTAssertTrue(recorded.history.deletedAt.isEmpty)
    }

    func testRemovedItemsAreRecordedAsDeleted() {
        let gone = TaskItem(title: "Gone")
        let category = TaskCategory(name: "Old", colorHex: "#000000")
        var previous = LibrarySnapshot(tasks: [gone], categories: [category])
        previous.history.modifiedAt = [gone.id: earlier, category.id: earlier]

        let recorded = LibrarySnapshot.empty.recordingChanges(since: previous, at: now)

        XCTAssertEqual(recorded.history.deletedAt, [gone.id: now, category.id: now])
        XCTAssertTrue(recorded.history.modifiedAt.isEmpty)
    }

    func testAddingOrRemovingIsNotReordering() {
        let a = TaskItem(title: "A"), b = TaskItem(title: "B"), c = TaskItem(title: "C")
        let previous = LibrarySnapshot(tasks: [a, b, c], categories: [])

        let recorded = LibrarySnapshot(tasks: [TaskItem(title: "New"), a, c], categories: [])
            .recordingChanges(since: previous, at: now)

        XCTAssertNil(recorded.history.taskOrderModifiedAt)
    }

    func testMovingATaskIsReordering() {
        let a = TaskItem(title: "A"), b = TaskItem(title: "B")
        let previous = LibrarySnapshot(tasks: [a, b], categories: [])

        let recorded = LibrarySnapshot(tasks: [b, a], categories: [])
            .recordingChanges(since: previous, at: now)

        XCTAssertEqual(recorded.history.taskOrderModifiedAt, now)
        XCTAssertTrue(recorded.history.modifiedAt.isEmpty, "Moving doesn't edit the tasks themselves")
    }

    func testOldDeletionsAreForgotten() {
        let oldID = UUID(), recentID = UUID()
        var previous = LibrarySnapshot.empty
        previous.history.deletedAt = [
            oldID: now.addingTimeInterval(-ChangeHistory.deletionRetention - 1),
            recentID: now.addingTimeInterval(-86_400),
        ]

        let recorded = LibrarySnapshot.empty.recordingChanges(since: previous, at: now)

        XCTAssertEqual(Array(recorded.history.deletedAt.keys), [recentID])
    }
}

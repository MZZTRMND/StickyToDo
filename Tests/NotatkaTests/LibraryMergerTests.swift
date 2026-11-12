import XCTest
@testable import Notatka

final class LibraryMergerTests: XCTestCase {
    private let t1 = Date(timeIntervalSinceReferenceDate: 1_000)
    private let t2 = Date(timeIntervalSinceReferenceDate: 2_000)
    private let t3 = Date(timeIntervalSinceReferenceDate: 3_000)

    private func snapshot(_ tasks: [TaskItem], modified: [UUID: Date] = [:], deleted: [UUID: Date] = [:], orderAt: Date? = nil) -> LibrarySnapshot {
        var snapshot = LibrarySnapshot(tasks: tasks, categories: [])
        snapshot.history.modifiedAt = modified
        snapshot.history.deletedAt = deleted
        snapshot.history.taskOrderModifiedAt = orderAt
        return snapshot
    }

    private func titles(_ snapshot: LibrarySnapshot) -> [String] {
        snapshot.tasks.map(\.title)
    }

    func testEmptyMacPicksUpEverything() {
        let category = TaskCategory(name: "Trip", colorHex: "#000000")
        var remote = snapshot([TaskItem(title: "Pack", categoryID: category.id), TaskItem(title: "Passport")])
        remote.categories = [category]

        let merged = LibraryMerger.merge(local: .empty, remote: remote)

        XCTAssertEqual(titles(merged), ["Pack", "Passport"])
        XCTAssertEqual(merged.categories, [category])
    }

    func testNewerEditWinsEitherWay() {
        var older = TaskItem(title: "Old title")
        var newer = older
        newer.title = "New title"
        older.isImportant = true

        let local = snapshot([older], modified: [older.id: t1])
        let remote = snapshot([newer], modified: [newer.id: t2])

        XCTAssertEqual(titles(LibraryMerger.merge(local: local, remote: remote)), ["New title"])
        XCTAssertEqual(titles(LibraryMerger.merge(local: remote, remote: local)), ["New title"])
        XCTAssertEqual(LibraryMerger.merge(local: local, remote: remote).history.modifiedAt[newer.id], t2)
    }

    func testDeletionBeatsAnEarlierEdit() {
        let task = TaskItem(title: "Done with it")
        let local = snapshot([], deleted: [task.id: t2])
        let remote = snapshot([task], modified: [task.id: t1])

        let merged = LibraryMerger.merge(local: local, remote: remote)

        XCTAssertTrue(merged.tasks.isEmpty)
        XCTAssertEqual(merged.history.deletedAt[task.id], t2)
    }

    func testDeletionBeatsAnItemWithNoHistory() {
        let task = TaskItem(title: "Saved before history was kept")
        let merged = LibraryMerger.merge(local: snapshot([task]), remote: snapshot([], deleted: [task.id: t1]))

        XCTAssertTrue(merged.tasks.isEmpty)
    }

    func testEditAfterDeletionBringsTheTaskBack() {
        let task = TaskItem(title: "Still needed")
        let local = snapshot([], deleted: [task.id: t1])
        let remote = snapshot([task], modified: [task.id: t2])

        let merged = LibraryMerger.merge(local: local, remote: remote)

        XCTAssertEqual(titles(merged), ["Still needed"])
        XCTAssertNil(merged.history.deletedAt[task.id])
    }

    func testTasksAddedOnBothMacsAreAllKept() {
        let shared = TaskItem(title: "Shared")
        let local = snapshot([TaskItem(title: "From this Mac"), shared])
        let remote = snapshot([TaskItem(title: "From the other Mac"), shared])

        let merged = LibraryMerger.merge(local: local, remote: remote)

        XCTAssertEqual(titles(merged), ["From the other Mac", "From this Mac", "Shared"])
    }

    func testLaterReorderWinsAndNewTasksKeepTheirPlace() {
        let a = TaskItem(title: "A"), b = TaskItem(title: "B"), c = TaskItem(title: "C")
        let added = TaskItem(title: "Added after B")
        // This Mac moved C to the top; the other added a task after B.
        let local = snapshot([c, a, b], orderAt: t2)
        let remote = snapshot([a, b, added, c], orderAt: t1)

        let merged = LibraryMerger.merge(local: local, remote: remote)

        XCTAssertEqual(titles(merged), ["C", "A", "B", "Added after B"])
        XCTAssertEqual(merged.history.taskOrderModifiedAt, t2)
    }

    func testMergingWithItselfChangesNothing() {
        let a = TaskItem(title: "A"), b = TaskItem(title: "B")
        let copy = snapshot([a, b], modified: [a.id: t1, b.id: t2], deleted: [UUID(): t3], orderAt: t1)

        XCTAssertEqual(LibraryMerger.merge(local: copy, remote: copy), copy)
    }
}

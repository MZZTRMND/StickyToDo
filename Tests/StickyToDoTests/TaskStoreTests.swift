import XCTest
import AppKit
@testable import StickyToDo

final class TaskStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var attachmentDirectory: URL!
    private var attachmentStore: AttachmentStore!

    override func setUp() {
        super.setUp()
        suiteName = "StickyToDoTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        attachmentDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        attachmentStore = AttachmentStore(directory: attachmentDirectory)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try? FileManager.default.removeItem(at: attachmentDirectory)
        attachmentStore = nil
        attachmentDirectory = nil
        super.tearDown()
    }

    private func makeStore() -> TaskStore {
        TaskStore(userDefaults: defaults, attachmentStore: attachmentStore)
    }

    private func makeTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return image
    }

    func testAddTaskTrimsWhitespaceAndInsertsAtFront() {
        let store = makeStore()
        store.addTask(title: "First")
        store.addTask(title: "  Second  ")

        XCTAssertEqual(store.tasks.map(\.title), ["Second", "First"])
    }

    func testAddTaskIgnoresBlankTitle() {
        let store = makeStore()
        store.addTask(title: "   ")

        XCTAssertTrue(store.tasks.isEmpty)
    }

    func testToggleDoneSetsDoneAt() {
        let store = makeStore()
        store.addTask(title: "Task")

        store.toggleDone(for: store.tasks[0])

        XCTAssertTrue(store.tasks[0].isDone)
        XCTAssertNotNil(store.tasks[0].doneAt)
    }

    func testToggleDoneTwiceClearsDoneAt() {
        let store = makeStore()
        store.addTask(title: "Task")
        let task = store.tasks[0]

        store.toggleDone(for: task)
        store.toggleDone(for: store.tasks[0])

        XCTAssertFalse(store.tasks[0].isDone)
        XCTAssertNil(store.tasks[0].doneAt)
    }

    func testDeleteRemovesTask() {
        let store = makeStore()
        store.addTask(title: "Task")
        let task = store.tasks[0]

        store.delete(task)

        XCTAssertTrue(store.tasks.isEmpty)
    }

    func testUpdateTitleTrimsAndIgnoresBlank() {
        let store = makeStore()
        store.addTask(title: "Original")
        let task = store.tasks[0]

        store.updateTitle(for: task, title: "  Updated  ")
        XCTAssertEqual(store.tasks[0].title, "Updated")

        store.updateTitle(for: store.tasks[0], title: "   ")
        XCTAssertEqual(store.tasks[0].title, "Updated")
    }

    func testSetImportant() {
        let store = makeStore()
        store.addTask(title: "Task")
        let task = store.tasks[0]

        store.setImportant(true, for: task)

        XCTAssertTrue(store.tasks[0].isImportant)
    }

    func testCreateCategoryDedupesCaseInsensitively() {
        let store = makeStore()
        let first = store.createCategory(name: "Work")
        let second = store.createCategory(name: "  work ")

        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(store.categories.count, 1)
    }

    func testCreateCategoryIgnoresBlankName() {
        let store = makeStore()
        let category = store.createCategory(name: "   ")

        XCTAssertNil(category)
        XCTAssertTrue(store.categories.isEmpty)
    }

    func testRenameCategoryRejectsDuplicateName() {
        let store = makeStore()
        guard let work = store.createCategory(name: "Work"),
              let personal = store.createCategory(name: "Personal") else {
            return XCTFail("Expected both categories to be created")
        }

        store.renameCategory(id: personal.id, to: "Work")

        XCTAssertEqual(store.categories.first { $0.id == personal.id }?.name, "Personal")
        XCTAssertEqual(store.categories.first { $0.id == work.id }?.name, "Work")
    }

    func testRenameCategoryAppliesTrimmedName() {
        let store = makeStore()
        guard let category = store.createCategory(name: "Work") else {
            return XCTFail("Expected category to be created")
        }

        store.renameCategory(id: category.id, to: "  Errands  ")

        XCTAssertEqual(store.categories.first { $0.id == category.id }?.name, "Errands")
    }

    func testDeleteCategoryClearsTaskReferences() {
        let store = makeStore()
        store.addTask(title: "Task")
        guard let category = store.createCategory(name: "Work") else {
            return XCTFail("Expected category to be created")
        }
        store.assignCategory(category.id, to: store.tasks[0])

        store.deleteCategory(id: category.id)

        XCTAssertTrue(store.categories.isEmpty)
        XCTAssertNil(store.tasks[0].categoryID)
    }

    func testAssignCategoryByTaskID() {
        let store = makeStore()
        store.addTask(title: "Task")
        guard let category = store.createCategory(name: "Work") else {
            return XCTFail("Expected category to be created")
        }

        store.assignCategory(category.id, toTaskID: store.tasks[0].id)

        XCTAssertEqual(store.tasks[0].categoryID, category.id)
    }

    func testMoveTaskReordersList() {
        let store = makeStore()
        store.addTask(title: "C")
        store.addTask(title: "B")
        store.addTask(title: "A")
        // tasks are now [A, B, C] (each addTask inserts at index 0)
        let aID = store.tasks[0].id
        let cID = store.tasks[2].id

        store.moveTask(from: aID, to: cID)

        // moveTask drops the source immediately before the target.
        XCTAssertEqual(store.tasks.map(\.title), ["B", "A", "C"])
    }

    func testMoveTaskIsNoOpForSameSourceAndTarget() {
        let store = makeStore()
        store.addTask(title: "A")
        let id = store.tasks[0].id

        store.moveTask(from: id, to: id)

        XCTAssertEqual(store.tasks.map(\.title), ["A"])
    }

    func testPurgeStaleCompletedTasksRemovesTasksDoneOnAPreviousDay() {
        let store = makeStore()
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = today.addingTimeInterval(-86_400)
        store.tasks = [
            TaskItem(title: "Done yesterday", isDone: true, doneAt: yesterday),
            TaskItem(title: "Done today", isDone: true, doneAt: today),
            TaskItem(title: "Still pending")
        ]

        let removedCount = store.purgeStaleCompletedTasks(referenceDate: today)

        XCTAssertEqual(removedCount, 1)
        XCTAssertEqual(store.tasks.map(\.title).sorted(), ["Done today", "Still pending"])
    }

    func testPurgeStaleCompletedTasksRemovesDoneTasksWithNoDoneAt() {
        let store = makeStore()
        store.tasks = [TaskItem(title: "Legacy done", isDone: true, doneAt: nil)]

        let removedCount = store.purgeStaleCompletedTasks()

        XCTAssertEqual(removedCount, 1)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    func testPurgeStaleCompletedTasksIsNoOpWhenNothingIsStale() {
        let store = makeStore()
        store.addTask(title: "Pending")
        let task = store.tasks[0]
        store.toggleDone(for: task)

        let removedCount = store.purgeStaleCompletedTasks()

        XCTAssertEqual(removedCount, 0)
        XCTAssertEqual(store.tasks.count, 1)
    }

    func testSetAttachmentStoresIDAndImageIsRetrievable() {
        let store = makeStore()
        store.addTask(title: "Task")
        let task = store.tasks[0]

        store.setAttachment(makeTestImage(), for: task)

        XCTAssertNotNil(store.tasks[0].attachmentID)
        XCTAssertNotNil(store.attachmentImage(for: store.tasks[0]))
    }

    func testSetAttachmentReplacesAndDeletesThePreviousFile() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.setAttachment(makeTestImage(), for: store.tasks[0])
        let firstID = store.tasks[0].attachmentID

        store.setAttachment(makeTestImage(), for: store.tasks[0])
        let secondID = store.tasks[0].attachmentID

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertNil(attachmentStore.loadImage(for: firstID!))
        XCTAssertNotNil(attachmentStore.loadImage(for: secondID!))
    }

    func testRemoveAttachmentClearsIDAndDeletesFile() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.setAttachment(makeTestImage(), for: store.tasks[0])
        let attachmentID = store.tasks[0].attachmentID!

        store.removeAttachment(for: store.tasks[0])

        XCTAssertNil(store.tasks[0].attachmentID)
        XCTAssertNil(attachmentStore.loadImage(for: attachmentID))
    }

    func testDeletingTaskCleansUpItsAttachmentFile() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.setAttachment(makeTestImage(), for: store.tasks[0])
        let task = store.tasks[0]
        let attachmentID = task.attachmentID!

        store.delete(task)

        XCTAssertNil(attachmentStore.loadImage(for: attachmentID))
    }

    func testAttachmentImageReturnsNilWhenTaskHasNoAttachment() {
        let store = makeStore()
        store.addTask(title: "Task")

        XCTAssertNil(store.attachmentImage(for: store.tasks[0]))
    }

    func testAddTaskWithAttachmentImageSavesItAtomically() {
        let store = makeStore()

        let created = store.addTask(title: "Task", attachmentImage: makeTestImage())

        XCTAssertNotNil(created?.attachmentID)
        XCTAssertNotNil(store.attachmentImage(for: store.tasks[0]))
    }
}

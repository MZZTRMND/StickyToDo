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
        TaskStore(persistence: UserDefaultsPersistence(defaults: defaults), attachmentStore: attachmentStore)
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

    func testAddAttachmentStoresIDAndImageIsRetrievable() {
        let store = makeStore()
        store.addTask(title: "Task")

        XCTAssertTrue(store.addAttachment(makeTestImage(), to: store.tasks[0]))

        XCTAssertEqual(store.tasks[0].attachmentIDs.count, 1)
        XCTAssertNotNil(store.attachmentImage(store.tasks[0].attachmentIDs[0]))
    }

    func testAddingMoreImagesKeepsTheEarlierOnesInOrder() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        let firstID = store.tasks[0].attachmentIDs[0]

        store.addAttachment(makeTestImage(), to: store.tasks[0])

        XCTAssertEqual(store.tasks[0].attachmentIDs.count, 2)
        XCTAssertEqual(store.tasks[0].attachmentIDs.first, firstID)
        XCTAssertNotNil(attachmentStore.loadImage(for: firstID))
    }

    func testATaskHoldsAtMostFourImages() {
        let store = makeStore()
        store.addTask(title: "Task")
        for _ in 0..<TaskItem.maxAttachments {
            XCTAssertTrue(store.addAttachment(makeTestImage(), to: store.tasks[0]))
        }
        XCTAssertFalse(store.tasks[0].canAddAttachment)

        XCTAssertFalse(store.addAttachment(makeTestImage(), to: store.tasks[0]))

        XCTAssertEqual(store.tasks[0].attachmentIDs.count, TaskItem.maxAttachments)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: attachmentDirectory.path)) ?? []
        // Each image is a full file plus its thumbnail; nothing extra saved.
        XCTAssertEqual(files.filter { $0.hasSuffix("-thumb.png") == false }.count, TaskItem.maxAttachments)
    }

    func testImagesSavedTogetherInTheBackgroundStopAtFour() {
        let backgroundAttachments = AttachmentStore(directory: attachmentDirectory, savesInBackground: true)
        let store = TaskStore(persistence: UserDefaultsPersistence(defaults: defaults), attachmentStore: backgroundAttachments)
        store.addTask(title: "Task")
        // Six drops at once: all start while the task still has room.
        for _ in 0..<6 {
            store.addAttachment(makeTestImage(), to: store.tasks[0])
        }
        let drained = expectation(description: "drained")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { DispatchQueue.main.async { drained.fulfill() } }
        wait(for: [drained], timeout: 5)

        XCTAssertEqual(store.tasks[0].attachmentIDs.count, TaskItem.maxAttachments)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: attachmentDirectory.path)) ?? []
        XCTAssertEqual(files.filter { $0.hasSuffix("-thumb.png") == false }.count, TaskItem.maxAttachments)
    }

    func testRemoveOneAttachmentKeepsTheOthers() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        let (first, second) = (store.tasks[0].attachmentIDs[0], store.tasks[0].attachmentIDs[1])

        store.removeAttachment(first, from: store.tasks[0])

        XCTAssertEqual(store.tasks[0].attachmentIDs, [second])
        XCTAssertNil(attachmentStore.loadImage(for: first))
        XCTAssertNotNil(attachmentStore.loadImage(for: second))
    }

    func testRemoveAllAttachmentsDeletesEveryFile() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        let ids = store.tasks[0].attachmentIDs

        store.removeAllAttachments(for: store.tasks[0])

        XCTAssertEqual(store.tasks[0].attachmentIDs, [])
        for id in ids {
            XCTAssertNil(attachmentStore.loadImage(for: id))
        }
    }

    func testDeletingTaskCleansUpAllItsAttachmentFiles() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        let task = store.tasks[0]

        store.delete(task)

        for id in task.attachmentIDs {
            XCTAssertNil(attachmentStore.loadImage(for: id))
        }
    }

    func testDeletingAStaleCopyOfATaskStillCleansUpImagesAddedSince() {
        let store = makeStore()
        store.addTask(title: "Task")
        let staleCopy = store.tasks[0]
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        let id = store.tasks[0].attachmentIDs[0]

        store.delete(staleCopy)

        XCTAssertNil(attachmentStore.loadImage(for: id))
    }

    func testAddTaskWithAttachmentImageSavesItAtomically() {
        let store = makeStore()

        let created = store.addTask(title: "Task", attachmentImage: makeTestImage())

        XCTAssertEqual(created?.attachmentIDs.count, 1)
        XCTAssertNotNil(store.attachmentImage(store.tasks[0].attachmentIDs[0]))
    }

    func testPurgeStaleCompletedTasksDeletesTheirAttachmentFiles() {
        let store = makeStore()
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = today.addingTimeInterval(-86_400)
        guard let staleImageID = attachmentStore.save(makeTestImage()),
              let keptImageID = attachmentStore.save(makeTestImage()) else {
            return XCTFail("Expected save to succeed")
        }
        store.tasks = [
            TaskItem(title: "Done yesterday", isDone: true, doneAt: yesterday, attachmentIDs: [staleImageID]),
            TaskItem(title: "Done today", isDone: true, doneAt: today, attachmentIDs: [keptImageID])
        ]

        store.purgeStaleCompletedTasks(referenceDate: today)

        XCTAssertFalse(FileManager.default.fileExists(atPath: attachmentStore.url(for: staleImageID).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentStore.url(for: keptImageID).path))
    }

    func testAFailedSaveLeavesTheImagesAsTheyWere() {
        let store = makeStore()
        store.addTask(title: "Task")
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        let oldID = store.tasks[0].attachmentIDs[0]

        // An empty NSImage has no bitmap, so it can't be saved as PNG.
        store.addAttachment(NSImage(), to: store.tasks[0])

        XCTAssertEqual(store.tasks[0].attachmentIDs, [oldID])
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentStore.url(for: oldID).path))
    }
    func testImageFinishingAfterItsTaskWasDeletedIsCleanedUp() {
        let backgroundAttachments = AttachmentStore(directory: attachmentDirectory, savesInBackground: true)
        let store = TaskStore(persistence: UserDefaultsPersistence(defaults: defaults), attachmentStore: backgroundAttachments)
        store.addTask(title: "Task")
        store.addAttachment(makeTestImage(), to: store.tasks[0])
        store.delete(store.tasks[0])

        // Let the background save finish and report back.
        let drained = expectation(description: "drained")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { DispatchQueue.main.async { drained.fulfill() } }
        wait(for: [drained], timeout: 5)

        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: attachmentDirectory.path)) ?? []
        XCTAssertEqual(leftovers, [])
    }

    func testOpenTaskCountsSkipDoneTasks() throws {
        let store = makeStore()
        let work = try XCTUnwrap(store.createCategory(name: "Work"))
        let home = try XCTUnwrap(store.createCategory(name: "Home"))
        _ = store.addTask(title: "w1", categoryID: work.id)
        let done = try XCTUnwrap(store.addTask(title: "w2", categoryID: work.id))
        _ = store.addTask(title: "w3", categoryID: work.id)
        _ = store.addTask(title: "loose")
        store.toggleDone(for: done)

        let counts = store.openTaskCounts()
        XCTAssertEqual(counts.all, 3)
        XCTAssertEqual(counts.byCategory[work.id], 2)
        XCTAssertNil(counts.byCategory[home.id])
    }

    func testCopyAttachmentPutsPNGAndTIFFOnThePasteboard() throws {
        let store = makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Design popup", attachmentImage: makeTestImage()))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("StickyToDoTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        XCTAssertTrue(store.copyAttachment(store.tasks[0].attachmentIDs[0], to: pasteboard))
        XCTAssertNotNil(pasteboard.data(forType: .png))
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
        XCTAssertNotNil(NSImage(pasteboard: pasteboard))

        XCTAssertFalse(store.copyAttachment(UUID(), to: pasteboard))
        _ = task
    }

    func testDragItemOffersTheImageFileAsACopy() throws {
        let store = makeStore()
        _ = store.addTask(title: "**Design** popup / v2", attachmentImage: makeTestImage())
        let task = store.tasks[0]
        let id = task.attachmentIDs[0]
        let provider = try XCTUnwrap(store.attachmentDragItem(id, of: task))
        XCTAssertEqual(provider.suggestedName, "Design popup   v2")
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier("public.png"))

        let loaded = expectation(description: "file")
        provider.loadFileRepresentation(forTypeIdentifier: "public.png") { url, _ in
            // The receiver gets a copy, never the attachment itself.
            XCTAssertNotNil(url)
            XCTAssertNotEqual(url?.standardizedFileURL, store.attachmentURL(for: id).standardizedFileURL)
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.attachmentURL(for: id).path))
    }

    func testAttachmentFileNameUsesThePlainFirstLine() {
        XCTAssertEqual(TaskStore.attachmentFileName(for: "Design *popup*\n- detail"), "Design popup")
        XCTAssertEqual(TaskStore.attachmentFileName(for: "   "), "Image")
        XCTAssertEqual(TaskStore.attachmentFileName(for: String(repeating: "a", count: 80)).count, 40)
    }

    func testThumbnailIsCachedAfterLoading() throws {
        let store = makeStore()
        _ = store.addTask(title: "Has image", attachmentImage: makeTestImage())
        let id = try XCTUnwrap(store.tasks[0].attachmentIDs.first)
        XCTAssertNil(store.cachedAttachmentThumbnail(for: id))
        var loaded: NSImage?
        store.loadAttachmentThumbnail(for: id) { loaded = $0 }
        XCTAssertNotNil(loaded)
        XCTAssertTrue(store.cachedAttachmentThumbnail(for: id) === loaded)
    }
}

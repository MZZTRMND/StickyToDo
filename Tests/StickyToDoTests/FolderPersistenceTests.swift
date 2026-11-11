import XCTest
@testable import StickyToDo

/// Two FolderPersistences on one folder stand in for two Macs sharing an
/// iCloud Drive folder: file coordination tells each about the other's
/// writes the same way it relays iCloud's.
final class FolderPersistenceTests: XCTestCase {
    private var folder: URL!
    private var persistences: [FolderPersistence] = []

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("FolderPersistenceTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        persistences.forEach { $0.stopWatching() }
        persistences = []
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    private func makePersistence() -> FolderPersistence {
        let persistence = FolderPersistence(folderURL: folder)
        persistences.append(persistence)
        return persistence
    }

    private func makeStore(_ persistence: FolderPersistence) -> TaskStore {
        TaskStore(persistence: persistence, attachmentStore: AttachmentStore(directory: persistence.attachmentsURL))
    }

    /// Runs the main loop until `condition` holds, so changes relayed to the
    /// main thread can arrive.
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while condition() == false && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertTrue(condition(), "Timed out", file: file, line: line)
    }

    private func snapshot(_ titles: String...) -> LibrarySnapshot {
        let tasks = titles.map { TaskItem(title: $0) }
        var snapshot = LibrarySnapshot(tasks: tasks, categories: [])
        for task in tasks {
            snapshot.history.modifiedAt[task.id] = Date()
        }
        return snapshot
    }

    func testSavedListLoadsBack() {
        let category = TaskCategory(name: "Trip", colorHex: "#000000")
        var saved = snapshot("Pack", "Passport")
        saved.categories = [category]
        saved.tasks[0].categoryID = category.id
        saved.history.taskOrderModifiedAt = Date()

        let first = makePersistence()
        _ = first.load()
        first.save(saved)
        first.flush()

        XCTAssertEqual(makePersistence().load(), saved)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.attachmentsURL.path))
    }

    func testSaveMergesWithWhatAnotherMacWrote() {
        let thisMac = makePersistence()
        _ = thisMac.load()
        let otherMac = makePersistence()
        _ = otherMac.load()

        otherMac.save(snapshot("From the other Mac"))
        otherMac.flush()
        thisMac.save(snapshot("From this Mac"))
        thisMac.flush()

        let titles = Set(makePersistence().load().tasks.map(\.title))
        XCTAssertEqual(titles, ["From the other Mac", "From this Mac"])
    }

    func testChangesFromAnotherMacAreReported() {
        let thisMac = makePersistence()
        _ = thisMac.load()
        var reported: LibrarySnapshot?
        thisMac.onExternalChange = { reported = $0 }

        let otherMac = makePersistence()
        _ = otherMac.load()
        otherMac.save(snapshot("New on the other Mac"))

        waitUntil { reported?.tasks.map(\.title) == ["New on the other Mac"] }
    }

    func testUnreadableFileIsNeverOverwritten() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let libraryURL = folder.appendingPathComponent(FolderPersistence.libraryFileName)
        let newerFormat = Data(#"{"formatVersion": 2, "tasks": [], "categories": [], "history": {}}"#.utf8)
        try newerFormat.write(to: libraryURL)

        let persistence = makePersistence()
        XCTAssertEqual(persistence.load(), .empty)
        persistence.save(snapshot("Would overwrite"))
        persistence.flush()

        XCTAssertEqual(try Data(contentsOf: libraryURL), newerFormat)
    }

    // MARK: Two TaskStores sharing a folder

    func testTwoMacsSeeEachOthersChanges() {
        let storeA = makeStore(makePersistence())
        let storeB = makeStore(makePersistence())

        let task = storeA.addTask(title: "Book the flight")!
        waitUntil { storeB.tasks.map(\.id) == [task.id] }

        storeB.updateTitle(for: storeB.tasks[0], title: "Book the flight to Madrid")
        waitUntil { storeA.tasks.first?.title == "Book the flight to Madrid" }

        storeA.delete(storeA.tasks[0])
        waitUntil { storeB.tasks.isEmpty }
    }

    func testDeletedCategoryIsClearedFromTasksOnTheOtherMac() {
        let storeA = makeStore(makePersistence())
        let storeB = makeStore(makePersistence())

        let category = storeA.createCategory(name: "Spain")!
        storeA.addTask(title: "Tapas", categoryID: category.id)
        waitUntil { storeB.tasks.first?.categoryID == category.id }

        storeB.deleteCategory(id: category.id)
        waitUntil { storeA.categories.isEmpty && storeA.tasks.first?.categoryID == nil }
    }

    func testNewMacPicksUpTheWholeList() {
        let storeA = makeStore(makePersistence())
        storeA.addTask(title: "One")
        storeA.addTask(title: "Two")
        persistences[0].flush()

        let storeB = makeStore(makePersistence())

        XCTAssertEqual(storeB.tasks.map(\.title), ["Two", "One"])
    }
}

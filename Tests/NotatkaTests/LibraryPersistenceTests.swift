import XCTest
@testable import Notatka

/// Records what TaskStore hands its persistence, without storing anything.
private final class InMemoryPersistence: LibraryPersistence {
    var stored: LibrarySnapshot
    private(set) var saveCount = 0
    var onExternalChange: ((LibrarySnapshot) -> Void)?
    func close() {}

    init(_ stored: LibrarySnapshot = .empty) {
        self.stored = stored
    }

    func load() -> LibrarySnapshot { stored }

    func save(_ snapshot: LibrarySnapshot) {
        stored = snapshot
        saveCount += 1
    }
}

final class LibraryPersistenceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var attachmentDirectory: URL!

    override func setUp() {
        super.setUp()
        suiteName = "NotatkaTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        attachmentDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: attachmentDirectory)
        super.tearDown()
    }

    private func makeStore(_ persistence: LibraryPersistence) -> TaskStore {
        TaskStore(persistence: persistence, attachmentStore: AttachmentStore(directory: attachmentDirectory))
    }

    // MARK: UserDefaultsPersistence

    func testLoadsListsSavedUnderTheOriginalKeys() throws {
        let category = TaskCategory(name: "Work", colorHex: "#FFAA00")
        let task = TaskItem(title: "Existing", categoryID: category.id)
        defaults.set(try JSONEncoder().encode([task]), forKey: "Notatka.tasks")
        defaults.set(try JSONEncoder().encode([category]), forKey: "Notatka.categories")

        let loaded = UserDefaultsPersistence(defaults: defaults).load()

        XCTAssertEqual(loaded, LibrarySnapshot(tasks: [task], categories: [category]))
    }

    func testSaveThenLoadRoundTrips() {
        let category = TaskCategory(name: "Home", colorHex: "#00AAFF")
        let snapshot = LibrarySnapshot(
            tasks: [TaskItem(title: "One", categoryID: category.id), TaskItem(title: "Two", isImportant: true)],
            categories: [category]
        )

        var withHistory = snapshot
        withHistory.history.modifiedAt = [category.id: Date(timeIntervalSinceReferenceDate: 100)]
        withHistory.history.deletedAt = [UUID(): Date(timeIntervalSinceReferenceDate: 200)]
        withHistory.history.taskOrderModifiedAt = Date(timeIntervalSinceReferenceDate: 300)

        UserDefaultsPersistence(defaults: defaults).save(withHistory)

        XCTAssertEqual(UserDefaultsPersistence(defaults: defaults).load(), withHistory)
    }

    func testStoreRecordsWhatChanged() {
        let persistence = InMemoryPersistence()
        let store = makeStore(persistence)

        let kept = store.addTask(title: "Keep")!
        let removed = store.addTask(title: "Remove")!
        store.delete(removed)

        XCTAssertNotNil(persistence.stored.history.modifiedAt[kept.id])
        XCTAssertNil(persistence.stored.history.modifiedAt[removed.id])
        XCTAssertNotNil(persistence.stored.history.deletedAt[removed.id])
    }

    func testHistoryCarriesOverBetweenLaunches() {
        let persistence = InMemoryPersistence()
        let first = makeStore(persistence)
        let task = first.addTask(title: "Task")!
        let stamped = persistence.stored.history.modifiedAt[task.id]

        let second = makeStore(persistence)
        second.addTask(title: "Another")

        XCTAssertEqual(persistence.stored.history.modifiedAt[task.id], stamped)
    }

    func testMissingOrUnreadableDataLoadsEmpty() {
        XCTAssertEqual(UserDefaultsPersistence(defaults: defaults).load(), .empty)

        defaults.set(Data("not json".utf8), forKey: "Notatka.tasks")
        XCTAssertEqual(UserDefaultsPersistence(defaults: defaults).load(), .empty)
    }

    // MARK: TaskStore and its persistence

    func testEveryChangeIsSaved() {
        let persistence = InMemoryPersistence()
        let store = makeStore(persistence)

        store.addTask(title: "Buy tickets")
        let category = store.createCategory(name: "Trip")
        store.assignCategory(category?.id, to: store.tasks[0])

        XCTAssertEqual(persistence.stored.tasks, store.tasks)
        XCTAssertEqual(persistence.stored.categories, store.categories)
        XCTAssertEqual(persistence.stored.tasks.first?.categoryID, category?.id)
    }

    func testLoadingACleanListDoesNotSave() {
        let persistence = InMemoryPersistence(LibrarySnapshot(tasks: [TaskItem(title: "Open")], categories: []))

        _ = makeStore(persistence)

        XCTAssertEqual(persistence.saveCount, 0)
    }

    func testCleanupOnLoadIsSaved() {
        let staleDone = TaskItem(title: "Old", isDone: true, doneAt: Date(timeIntervalSinceNow: -3 * 86_400))
        let orphaned = TaskItem(title: "Orphan", categoryID: UUID())
        let persistence = InMemoryPersistence(LibrarySnapshot(tasks: [staleDone, orphaned], categories: []))

        _ = makeStore(persistence)

        XCTAssertEqual(persistence.saveCount, 1)
        XCTAssertEqual(persistence.stored.tasks.map(\.title), ["Orphan"])
        XCTAssertNil(persistence.stored.tasks.first?.categoryID)
    }
}

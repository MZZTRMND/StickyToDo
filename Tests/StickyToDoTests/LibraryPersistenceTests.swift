import XCTest
@testable import StickyToDo

/// Records what TaskStore hands its persistence, without storing anything.
private final class InMemoryPersistence: LibraryPersistence {
    var stored: LibrarySnapshot
    private(set) var saveCount = 0

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
        suiteName = "StickyToDoTests.\(UUID().uuidString)"
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
        defaults.set(try JSONEncoder().encode([task]), forKey: "StickyToDo.tasks")
        defaults.set(try JSONEncoder().encode([category]), forKey: "StickyToDo.categories")

        let loaded = UserDefaultsPersistence(defaults: defaults).load()

        XCTAssertEqual(loaded, LibrarySnapshot(tasks: [task], categories: [category]))
    }

    func testSaveThenLoadRoundTrips() {
        let category = TaskCategory(name: "Home", colorHex: "#00AAFF")
        let snapshot = LibrarySnapshot(
            tasks: [TaskItem(title: "One", categoryID: category.id), TaskItem(title: "Two", isImportant: true)],
            categories: [category]
        )

        UserDefaultsPersistence(defaults: defaults).save(snapshot)

        XCTAssertEqual(UserDefaultsPersistence(defaults: defaults).load(), snapshot)
    }

    func testMissingOrUnreadableDataLoadsEmpty() {
        XCTAssertEqual(UserDefaultsPersistence(defaults: defaults).load(), .empty)

        defaults.set(Data("not json".utf8), forKey: "StickyToDo.tasks")
        XCTAssertEqual(UserDefaultsPersistence(defaults: defaults).load(), .empty)
    }

    // MARK: TaskStore and its persistence

    func testEveryChangeIsSaved() {
        let persistence = InMemoryPersistence()
        let store = makeStore(persistence)

        store.addTask(title: "Buy tickets")
        let category = store.createCategory(name: "Trip")
        store.assignCategory(category?.id, to: store.tasks[0])

        XCTAssertEqual(persistence.stored, LibrarySnapshot(tasks: store.tasks, categories: store.categories))
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

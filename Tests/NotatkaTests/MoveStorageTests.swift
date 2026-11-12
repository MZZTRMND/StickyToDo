import XCTest
import AppKit
@testable import Notatka

/// Turning iCloud sync on and off: TaskStore.moveStorage between this Mac's
/// storage (a private UserDefaults suite and attachments folder) and a
/// shared folder.
final class MoveStorageTests: XCTestCase {
    private var root: URL!
    private var suiteNames: [String] = []
    private var folderPersistences: [FolderPersistence] = []

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("MoveStorageTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        folderPersistences.forEach { $0.close() }
        folderPersistences = []
        suiteNames.forEach { UserDefaults().removePersistentDomain(forName: $0) }
        suiteNames = []
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    /// One Mac's own storage.
    private func thisMacStorage(_ name: String) -> (UserDefaultsPersistence, AttachmentStore) {
        let suiteName = "MoveStorageTests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        return (
            UserDefaultsPersistence(defaults: UserDefaults(suiteName: suiteName)!),
            AttachmentStore(directory: root.appendingPathComponent("\(name)-attachments"))
        )
    }

    /// The shared iCloud Drive folder, as one Mac sees it.
    private func sharedStorage() -> (FolderPersistence, AttachmentStore) {
        let persistence = FolderPersistence(folderURL: root.appendingPathComponent("iCloud"))
        folderPersistences.append(persistence)
        return (persistence, AttachmentStore(directory: persistence.attachmentsURL))
    }

    private func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return image
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while condition() == false && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertTrue(condition(), "Timed out", file: file, line: line)
    }

    func testTurningSyncOnMovesTasksAndImagesToTheFolder() {
        let (local, localImages) = thisMacStorage("mac")
        let store = TaskStore(persistence: local, attachmentStore: localImages)
        let task = store.addTask(title: "With a photo", attachmentImage: makeImage())!
        let imageID = store.tasks[0].attachmentIDs[0]

        let (shared, sharedImages) = sharedStorage()
        store.moveStorage(to: shared, attachments: sharedImages)
        shared.flush()

        XCTAssertEqual(store.tasks.map(\.id), [task.id])
        XCTAssertEqual(store.attachmentURL(for: imageID), sharedImages.url(for: imageID))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedImages.url(for: imageID).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: localImages.url(for: imageID).path), "The original stays")
        XCTAssertEqual(sharedStorage().0.load().tasks.map(\.id), [task.id])
    }

    func testNewMacJoiningKeepsItsOwnTasksAndGetsTheOthers() {
        let (homeLocal, homeImages) = thisMacStorage("home")
        let home = TaskStore(persistence: homeLocal, attachmentStore: homeImages)
        home.addTask(title: "From home")
        let (homeShared, homeSharedImages) = sharedStorage()
        home.moveStorage(to: homeShared, attachments: homeSharedImages)
        homeShared.flush()

        let (laptopLocal, laptopImages) = thisMacStorage("laptop")
        let laptop = TaskStore(persistence: laptopLocal, attachmentStore: laptopImages)
        laptop.addTask(title: "From the laptop")
        let (laptopShared, laptopSharedImages) = sharedStorage()
        laptop.moveStorage(to: laptopShared, attachments: laptopSharedImages)

        XCTAssertEqual(Set(laptop.tasks.map(\.title)), ["From home", "From the laptop"])
        waitUntil { Set(home.tasks.map(\.title)) == ["From home", "From the laptop"] }
    }

    func testTurningSyncOffKeepsTheSyncedList() {
        let (local, localImages) = thisMacStorage("mac")
        let store = TaskStore(persistence: local, attachmentStore: localImages)
        let beforeSync = store.addTask(title: "Before sync")!
        let (shared, sharedImages) = sharedStorage()
        store.moveStorage(to: shared, attachments: sharedImages)

        store.delete(beforeSync)
        store.addTask(title: "Added while syncing", attachmentImage: makeImage())
        let imageID = store.tasks[0].attachmentIDs[0]

        store.moveStorage(to: local, attachments: localImages)

        XCTAssertEqual(store.tasks.map(\.title), ["Added while syncing"])
        XCTAssertEqual(local.load().tasks.map(\.title), ["Added while syncing"], "The deleted task doesn't come back")
        XCTAssertTrue(FileManager.default.fileExists(atPath: localImages.url(for: imageID).path))
    }
}

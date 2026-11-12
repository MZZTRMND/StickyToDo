import AppKit
import XCTest
@testable import Notatka

final class StickyToDoMigrationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var root: URL!

    override func setUp() {
        super.setUp()
        suiteName = "NotatkaTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        root = FileManager.default.temporaryDirectory.appendingPathComponent("StickyToDoMigrationTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    private func folder(_ name: String) -> URL {
        root.appendingPathComponent(name, isDirectory: true)
    }

    private func makeMigration(legacySettings: [String: Any] = [:]) -> StickyToDoMigration {
        StickyToDoMigration(
            legacySettings: legacySettings,
            defaults: defaults,
            legacyAttachmentsFolder: folder("StickyToDo/Attachments"),
            attachmentsFolder: folder("Notatka/Attachments"),
            legacyICloudFolder: folder("iCloud/StickyToDo"),
            iCloudFolder: folder("iCloud/Notatka")
        )
    }

    private func encoded<Value: Encodable>(_ value: Value) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func saveImage(in folder: URL) -> UUID {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return AttachmentStore(directory: folder).save(image)!
    }

    // MARK: Settings and this Mac's list

    func testCopiesSettingsAndListUnderNotatkasKeys() throws {
        let task = TaskItem(title: "Buy milk")
        let migration = makeMigration(legacySettings: [
            "StickyToDo.appearance": "dark",
            "StickyToDo.tasks": try encoded([task]),
            "NSWindow Frame main": "0 0 100 100",
        ])

        migration.runIfNeeded()

        XCTAssertEqual(defaults.string(forKey: "Notatka.appearance"), "dark")
        XCTAssertEqual(defaults.string(forKey: "NSWindow Frame main"), "0 0 100 100")
        XCTAssertNil(defaults.object(forKey: "StickyToDo.appearance"))
        XCTAssertEqual(UserDefaultsPersistence(defaults: defaults).load().tasks, [task])
        XCTAssertTrue(defaults.bool(forKey: StickyToDoMigration.migratedKey))
    }

    func testKeepsSettingsNotatkaAlreadyHas() {
        defaults.set("light", forKey: "Notatka.appearance")

        makeMigration(legacySettings: ["StickyToDo.appearance": "dark"]).runIfNeeded()

        XCTAssertEqual(defaults.string(forKey: "Notatka.appearance"), "light")
    }

    func testRunsOnlyOnce() {
        makeMigration(legacySettings: ["StickyToDo.appearance": "dark"]).runIfNeeded()
        defaults.removeObject(forKey: "Notatka.appearance")

        makeMigration(legacySettings: ["StickyToDo.appearance": "dark"]).runIfNeeded()

        XCTAssertNil(defaults.object(forKey: "Notatka.appearance"))
    }

    func testCopiesThisMacsImages() throws {
        let imageID = saveImage(in: folder("StickyToDo/Attachments"))
        let task = TaskItem(title: "Sketch", attachmentIDs: [imageID])

        makeMigration(legacySettings: ["StickyToDo.tasks": try encoded([task])]).runIfNeeded()

        let images = AttachmentStore(directory: folder("Notatka/Attachments"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: images.url(for: imageID).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder("StickyToDo/Attachments").path), "StickyToDo's images stay put")
    }

    // MARK: iCloud Drive

    private func saveList(_ snapshot: LibrarySnapshot, in folder: URL) {
        let persistence = FolderPersistence(folderURL: folder)
        persistence.save(snapshot)
        persistence.close()
    }

    private func loadList(in folder: URL) -> LibrarySnapshot {
        let persistence = FolderPersistence(folderURL: folder)
        defer { persistence.close() }
        return persistence.load()
    }

    func testMergesICloudDriveListWhenSyncIsOn() {
        let legacyFolder = folder("iCloud/StickyToDo")
        let imageID = saveImage(in: legacyFolder.appendingPathComponent("Attachments"))
        let fromStickyToDo = TaskItem(title: "Old Mac's task", attachmentIDs: [imageID])
        let fromOtherMac = TaskItem(title: "Already in Notatka")
        saveList(LibrarySnapshot(tasks: [fromStickyToDo], categories: []), in: legacyFolder)
        saveList(LibrarySnapshot(tasks: [fromOtherMac], categories: []), in: folder("iCloud/Notatka"))

        makeMigration(legacySettings: ["StickyToDo.syncWithICloud": true]).runIfNeeded()

        let merged = loadList(in: folder("iCloud/Notatka"))
        XCTAssertEqual(Set(merged.tasks.map(\.title)), ["Old Mac's task", "Already in Notatka"])
        let images = AttachmentStore(directory: folder("iCloud/Notatka/Attachments"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: images.url(for: imageID).path))
        XCTAssertEqual(loadList(in: legacyFolder).tasks, [fromStickyToDo], "StickyToDo's list is left as it was")
    }

    func testLeavesICloudDriveAloneWhenSyncIsOff() {
        saveList(LibrarySnapshot(tasks: [TaskItem(title: "Synced")], categories: []), in: folder("iCloud/StickyToDo"))

        makeMigration().runIfNeeded()

        XCTAssertFalse(FileManager.default.fileExists(atPath: folder("iCloud/Notatka").path))
        XCTAssertTrue(defaults.bool(forKey: StickyToDoMigration.migratedKey))
    }

    func testRunsAgainWhenICloudDriveListCantBeReadYet() throws {
        let legacyFolder = folder("iCloud/StickyToDo")
        try FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true)
        try Data("not downloaded".utf8).write(to: legacyFolder.appendingPathComponent(FolderPersistence.libraryFileName))

        makeMigration(legacySettings: ["StickyToDo.syncWithICloud": true]).runIfNeeded()

        XCTAssertFalse(defaults.bool(forKey: StickyToDoMigration.migratedKey))
    }
}

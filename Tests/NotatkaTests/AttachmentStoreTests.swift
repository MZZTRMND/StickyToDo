import XCTest
import AppKit
@testable import Notatka

final class AttachmentStoreTests: XCTestCase {
    private var directory: URL!
    private var store: AttachmentStore!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = AttachmentStore(directory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        store = nil
        directory = nil
        super.tearDown()
    }

    private func makeTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return image
    }

    func testSaveWritesAFileAndReturnsAnID() {
        let id = store.save(makeTestImage())

        XCTAssertNotNil(id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: id!).path))
    }

    func testLoadImageRoundTrips() {
        guard let id = store.save(makeTestImage()) else {
            return XCTFail("Expected save to succeed")
        }

        let loaded = store.loadImage(for: id)

        XCTAssertNotNil(loaded)
    }

    func testLoadImageReturnsNilForUnknownID() {
        XCTAssertNil(store.loadImage(for: UUID()))
    }

    func testDeleteRemovesTheFile() {
        guard let id = store.save(makeTestImage()) else {
            return XCTFail("Expected save to succeed")
        }

        store.delete(id: id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: id).path))
        XCTAssertNil(store.loadImage(for: id))
    }
    private func makeLargeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 1000, height: 500))
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 1000, height: 500).fill()
        image.unlockFocus()
        return image
    }

    private func loadThumbnailSync(_ store: AttachmentStore, _ id: UUID) -> NSImage? {
        var result: NSImage?
        store.loadThumbnail(for: id) { result = $0 }
        return result
    }

    func testSaveWritesASmallThumbnail() throws {
        let id = try XCTUnwrap(store.save(makeLargeImage()))

        let thumbnail = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: store.thumbnailURL(for: id))))
        XCTAssertLessThanOrEqual(max(thumbnail.pixelsWide, thumbnail.pixelsHigh), AttachmentStore.thumbnailMaxPixels)
        XCTAssertEqual(Double(thumbnail.pixelsWide) / Double(thumbnail.pixelsHigh), 2, accuracy: 0.05)
    }

    func testThumbnailIsMadeForImagesSavedWithoutOne() throws {
        let id = try XCTUnwrap(store.save(makeLargeImage()))
        try FileManager.default.removeItem(at: store.thumbnailURL(for: id))

        XCTAssertNotNil(loadThumbnailSync(store, id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.thumbnailURL(for: id).path))
    }

    func testDeleteRemovesTheThumbnailToo() throws {
        let id = try XCTUnwrap(store.save(makeLargeImage()))

        store.delete(id: id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.thumbnailURL(for: id).path))
        XCTAssertNil(loadThumbnailSync(store, id))
    }

    func testBackgroundSaveCallsBackOnTheMainThread() {
        let backgroundStore = AttachmentStore(directory: directory, savesInBackground: true)
        let saved = expectation(description: "saved")
        backgroundStore.save(makeTestImage()) { id in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNotNil(id)
            saved.fulfill()
        }
        wait(for: [saved], timeout: 5)
    }
}

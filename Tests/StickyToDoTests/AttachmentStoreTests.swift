import XCTest
import AppKit
@testable import StickyToDo

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
}

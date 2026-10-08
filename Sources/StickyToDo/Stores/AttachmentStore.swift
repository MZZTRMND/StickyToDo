import AppKit

/// Reads/writes attachment images as PNG files on disk, keyed by UUID.
/// Tasks only carry a UUID reference (TaskItem.attachmentID); the image
/// bytes never touch the UserDefaults-backed task JSON blob.
final class AttachmentStore {
    private let directory: URL
    // ContentView re-evaluates its task list on every render (any hover,
    // animation, or state change anywhere in the view), and previously
    // called loadImage(for:) fresh each time - a synchronous disk read +
    // decode per attached task, per render, on the main thread. Caching by
    // id turns that into a one-time cost per attachment.
    private var imageCache: [UUID: NSImage] = [:]

    init(directory: URL = AttachmentStore.defaultDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("StickyToDo/Attachments", isDirectory: true)
    }

    func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).png")
    }

    @discardableResult
    func save(_ image: NSImage) -> UUID? {
        guard let data = image.pngData() else { return nil }
        let id = UUID()
        do {
            try data.write(to: url(for: id))
            return id
        } catch {
            return nil
        }
    }

    func loadImage(for id: UUID) -> NSImage? {
        if let cached = imageCache[id] {
            return cached
        }
        let image = NSImage(contentsOf: url(for: id))
        imageCache[id] = image
        return image
    }

    func delete(id: UUID) {
        imageCache[id] = nil
        try? FileManager.default.removeItem(at: url(for: id))
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

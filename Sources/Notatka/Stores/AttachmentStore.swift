import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Reads/writes attachment images as PNG files on disk, keyed by UUID.
/// Tasks only carry a UUID reference (TaskItem.attachmentIDs); the image
/// bytes never touch the saved task list (LibraryPersistence).
///
/// Next to each image it keeps a small thumbnail for the hover preview, so
/// the card never decodes a full-size image (a 5K screenshot took ~150 ms
/// and 59 MB of memory) just to show it at 120 pt.
final class AttachmentStore {
    /// Longest side of a thumbnail, in pixels: the 120 pt preview at 2x.
    static let thumbnailMaxPixels = 240

    private let directory: URL
    /// nil runs everything synchronously (tests); the app uses a background
    /// queue, so converting a big pasted screenshot to PNG (~90 ms) doesn't
    /// freeze the UI.
    private let workQueue: DispatchQueue?
    /// Thumbnails only - they're small. Main thread only.
    private var thumbnailCache: [UUID: NSImage] = [:]

    init(directory: URL = AttachmentStore.defaultDirectory, savesInBackground: Bool = false) {
        self.directory = directory
        self.workQueue = savesInBackground
            ? DispatchQueue(label: "Notatka.attachments", qos: .userInitiated)
            : nil
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static var defaultDirectory: URL {
        localDirectory(for: .notatka, bundleID: Bundle.main.bundleIdentifier)
    }

    /// Where `identity`'s build `bundleID` keeps images when the list is on
    /// this Mac only.
    static func localDirectory(for identity: AppIdentity, bundleID: String?) -> URL {
        identity.applicationSupportFolder(forBundleID: bundleID)
            .appendingPathComponent("Attachments", isDirectory: true)
    }

    func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).png")
    }

    func thumbnailURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString)-thumb.png")
    }

    // MARK: Saving

    /// Saves the image and its thumbnail, then calls `completion` on the main
    /// thread with the new id, or nil if it couldn't be saved. Runs
    /// synchronously when the store has no background queue.
    func save(_ image: NSImage, completion: @escaping (UUID?) -> Void) {
        // Taken here, on the calling (main) thread: NSImage isn't safe to
        // share across threads, a CGImage is. For a bitmap this is cheap -
        // the encoding below is the slow part.
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }
        perform { self.writeFiles(for: cgImage) } completion: { completion($0) }
    }

    /// Synchronous save, always on the calling thread.
    @discardableResult
    func save(_ image: NSImage) -> UUID? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return writeFiles(for: cgImage)
    }

    private func writeFiles(for image: CGImage) -> UUID? {
        let id = UUID()
        guard Self.writePNG(image, to: url(for: id)) else { return nil }
        if let thumbnail = Self.downscaled(image, maxPixels: Self.thumbnailMaxPixels) {
            _ = Self.writePNG(thumbnail, to: thumbnailURL(for: id))
        }
        return id
    }

    // MARK: Loading

    /// The full-size image. Not cached: the card only ever shows thumbnails.
    func loadImage(for id: UUID) -> NSImage? {
        NSImage(contentsOf: url(for: id))
    }

    /// The small preview image, from the cache, the thumbnail file, or - for
    /// attachments saved before thumbnails existed - made from the full image
    /// once and saved. `completion` runs on the main thread.
    func loadThumbnail(for id: UUID, completion: @escaping (NSImage?) -> Void) {
        if let cached = thumbnailCache[id] {
            completion(cached)
            return
        }
        let fullURL = url(for: id)
        let thumbURL = thumbnailURL(for: id)
        perform { () -> NSImage? in
            if let existing = NSImage(contentsOf: thumbURL) {
                return existing
            }
            // ImageIO can scale while decoding, without building the
            // full-size bitmap in memory.
            guard let source = CGImageSourceCreateWithURL(fullURL as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaxPixels,
                  ] as CFDictionary) else { return nil }
            _ = Self.writePNG(thumbnail, to: thumbURL)
            return NSImage(cgImage: thumbnail, size: .zero)
        } completion: { [weak self] image in
            if let image {
                self?.thumbnailCache[id] = image
            }
            completion(image)
        }
    }

    /// The thumbnail if it's already loaded; never touches the disk.
    func cachedThumbnail(for id: UUID) -> NSImage? {
        thumbnailCache[id]
    }

    /// Copies these images (and their thumbnails) from `source` when this
    /// store doesn't have them yet - when the task list moves to another
    /// folder. The originals stay where they were.
    func copyMissingFiles(for ids: [UUID], from source: AttachmentStore) {
        let fileManager = FileManager.default
        for id in ids {
            for (from, to) in [(source.url(for: id), url(for: id)), (source.thumbnailURL(for: id), thumbnailURL(for: id))]
            where fileManager.fileExists(atPath: to.path) == false {
                try? fileManager.copyItem(at: from, to: to)
            }
        }
    }

    func delete(id: UUID) {
        thumbnailCache[id] = nil
        try? FileManager.default.removeItem(at: url(for: id))
        try? FileManager.default.removeItem(at: thumbnailURL(for: id))
    }

    // MARK: Helpers

    /// Runs `work` on the background queue (or right here, without one) and
    /// hands its result to `completion` on the main thread.
    private func perform<T>(_ work: @escaping () -> T, completion: @escaping (T) -> Void) {
        guard let workQueue else {
            completion(work())
            return
        }
        workQueue.async {
            let result = work()
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    private static func downscaled(_ image: CGImage, maxPixels: Int) -> CGImage? {
        let scale = min(1, Double(maxPixels) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

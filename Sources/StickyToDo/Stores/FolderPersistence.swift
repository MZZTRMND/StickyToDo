import AppKit
import Foundation

/// Keeps the task list in a folder - meant for one in iCloud Drive, so every
/// Mac signed in to the same account shares it:
///
///     <folder>/library.json    tasks, categories and their change history
///     <folder>/Attachments/    images (an AttachmentStore pointed here)
///
/// Another Mac may change library.json at any time, so nothing is ever
/// written blindly: every save reads the file (and any conflicting copies
/// iCloud kept when two Macs wrote at once), merges them with LibraryMerger,
/// and writes the result. Changes arriving from elsewhere are picked up by
/// watching the folder (as an NSFilePresenter), plus a re-read whenever the
/// app becomes active, and handed to TaskStore through `onExternalChange`.
///
/// All file work happens on a private serial queue, so a slow iCloud read
/// never holds up the UI - except `load()`, which the app needs before it
/// can show anything.
final class FolderPersistence: NSObject, LibraryPersistence, NSFilePresenter {
    static let libraryFileName = "library.json"
    static let attachmentsFolderName = "Attachments"

    let folderURL: URL
    let libraryURL: URL
    var attachmentsURL: URL { folderURL.appendingPathComponent(Self.attachmentsFolderName, isDirectory: true) }

    var onExternalChange: ((LibrarySnapshot) -> Void)?

    private let ioQueue = DispatchQueue(label: "StickyToDo.libraryFolder", qos: .userInitiated)
    let presentedItemOperationQueue: OperationQueue
    /// The folder, not the file: library.json may not exist yet, and iCloud
    /// replaces it rather than editing it in place - watching the folder
    /// hears about it either way.
    var presentedItemURL: URL? { folderURL }

    /// The list as last read from or written to the file. ioQueue only.
    private var lastKnown: LibrarySnapshot?
    private var activationObserver: NSObjectProtocol?
    private var isWatching = false

    init(folderURL: URL) {
        // File coordination matches presenters by path, so use the real one
        // rather than one through a symlink (/var -> /private/var).
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let folderURL = folderURL.resolvingSymlinksInPath()
        self.folderURL = folderURL
        self.libraryURL = folderURL.appendingPathComponent(Self.libraryFileName)
        presentedItemOperationQueue = OperationQueue()
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue.underlyingQueue = ioQueue
        super.init()

        try? FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        NSFileCoordinator.addFilePresenter(self)
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.refresh()
        }
        isWatching = true
    }

    deinit {
        stopWatching()
    }

    /// Stops following the folder. The file-coordination registry holds on
    /// to presenters, so this must be called before letting go of one.
    func stopWatching() {
        guard isWatching else { return }
        isWatching = false
        NSFileCoordinator.removeFilePresenter(self)
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    // MARK: LibraryPersistence

    func load() -> LibrarySnapshot {
        ioQueue.sync {
            let stored = syncWithFile(merging: nil)
            lastKnown = stored
            return stored
        }
    }

    func save(_ snapshot: LibrarySnapshot) {
        ioQueue.async { [self] in
            guard snapshot != lastKnown else { return }
            syncAndReport(merging: snapshot)
        }
    }

    /// Waits until every save so far is written.
    func flush() {
        ioQueue.sync {}
    }

    func close() {
        stopWatching()
        flush()
    }

    /// Re-reads the folder and reports any change made elsewhere.
    func refresh() {
        ioQueue.async { [self] in
            syncAndReport(merging: nil)
        }
    }

    // MARK: NSFilePresenter (called on ioQueue)

    func presentedSubitemDidChange(at url: URL) {
        guard isLibraryFile(url) else { return }
        syncAndReport(merging: nil)
    }

    func presentedSubitem(at url: URL, didGain version: NSFileVersion) {
        guard isLibraryFile(url) else { return }
        syncAndReport(merging: nil)
    }

    private func isLibraryFile(_ url: URL) -> Bool {
        url.resolvingSymlinksInPath().standardizedFileURL == libraryURL.standardizedFileURL
    }

    // MARK: Reading and writing (ioQueue only)

    /// Syncs, then tells TaskStore if the result holds anything it didn't
    /// hand over itself.
    private func syncAndReport(merging local: LibrarySnapshot?) {
        let expected = local ?? lastKnown
        let merged = syncWithFile(merging: local)
        lastKnown = merged
        guard merged != expected else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onExternalChange?(merged)
        }
    }

    /// Merges `local` - or, when there's nothing new to save, the list as
    /// last known, so edits made while the file couldn't be read still
    /// reach it - with the file and any conflicting copies of it, writes the
    /// result back if it differs from the file, and returns it. A file that
    /// exists but can't be read (still downloading, damaged, or from a newer
    /// StickyToDo) is never overwritten.
    private func syncWithFile(merging local: LibrarySnapshot?) -> LibrarySnapshot {
        let local = local ?? lastKnown
        var result = local ?? .empty
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: self).coordinate(
            writingItemAt: libraryURL, options: .forMerging, error: &coordinationError
        ) { url in
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            let stored = Self.read(url)
            if fileExists && stored == nil {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                return
            }

            let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
            var merged = stored ?? .empty
            for conflict in conflicts {
                if let copy = Self.read(conflict.url) {
                    merged = LibraryMerger.merge(local: merged, remote: copy)
                }
            }
            if let local {
                merged = LibraryMerger.merge(local: local, remote: merged)
            }

            if merged != stored {
                guard Self.write(merged, to: url) else { return }
            }
            for conflict in conflicts {
                conflict.isResolved = true
            }
            if conflicts.isEmpty == false {
                try? NSFileVersion.removeOtherVersionsOfItem(at: url)
            }
            result = merged
        }
        return result
    }

    /// library.json's layout. `formatVersion` lets a future StickyToDo change
    /// it: this one refuses (and so never overwrites) a newer format.
    private struct LibraryFile: Codable {
        static let currentFormatVersion = 1

        var formatVersion: Int
        var tasks: [TaskItem]
        var categories: [TaskCategory]
        var history: ChangeHistory
    }

    private static func read(_ url: URL) -> LibrarySnapshot? {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(LibraryFile.self, from: data),
              file.formatVersion <= LibraryFile.currentFormatVersion
        else { return nil }
        return LibrarySnapshot(tasks: file.tasks, categories: file.categories, history: file.history)
    }

    private static func write(_ snapshot: LibrarySnapshot, to url: URL) -> Bool {
        let file = LibraryFile(
            formatVersion: LibraryFile.currentFormatVersion,
            tasks: snapshot.tasks,
            categories: snapshot.categories,
            history: snapshot.history
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(file) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

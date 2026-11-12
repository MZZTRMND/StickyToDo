import Foundation

/// Notatka used to be called StickyToDo, and kept its data under that name
/// (AppIdentity.stickyToDo). On Notatka's first launch on a Mac this brings
/// that data over, before anything reads the settings or the list:
///
/// - Settings and this Mac's task list are copied from StickyToDo's defaults
///   domain, renamed to Notatka's keys. A key Notatka already has is kept.
/// - This Mac's images are copied to Notatka's Application Support folder.
/// - With Sync on, iCloud Drive's StickyToDo list is merged into Notatka's
///   with LibraryMerger, the way turning Sync on merges two lists, and its
///   images are copied. Merged rather than copied, because another Mac may
///   already have brought the shared list over, and this Mac's StickyToDo
///   may have changed it since.
///
/// StickyToDo's data is only read, never changed, so it stays as a backup.
/// Every step is safe to repeat, so if iCloud Drive's list can't be read
/// yet, the migration simply runs again next launch.
struct StickyToDoMigration {
    static let migratedKey = AppIdentity.notatka.settingsKeyPrefix + "migratedFromStickyToDo"

    /// StickyToDo's defaults domain.
    var legacySettings: [String: Any]
    var defaults: UserDefaults
    var legacyAttachmentsFolder: URL
    var attachmentsFolder: URL
    /// nil when iCloud Drive is off.
    var legacyICloudFolder: URL?
    var iCloudFolder: URL?

    /// The migration for the running build - the real app from StickyToDo's,
    /// the test build from StickyToDo's test build - or nil for builds
    /// StickyToDo never had (`swift run`, tests).
    static func forRunningBuild(bundleID: String? = Bundle.main.bundleIdentifier) -> StickyToDoMigration? {
        guard let legacyBundleID = AppIdentity.notatka.counterpart(of: bundleID, in: .stickyToDo) else { return nil }
        return StickyToDoMigration(
            legacySettings: UserDefaults.standard.persistentDomain(forName: legacyBundleID) ?? [:],
            defaults: .standard,
            legacyAttachmentsFolder: AttachmentStore.localDirectory(for: .stickyToDo, bundleID: legacyBundleID),
            attachmentsFolder: AttachmentStore.localDirectory(for: .notatka, bundleID: bundleID),
            legacyICloudFolder: LibraryLocation.iCloudDriveFolder(for: .stickyToDo, bundleID: legacyBundleID),
            iCloudFolder: LibraryLocation.iCloudDriveFolder(for: .notatka, bundleID: bundleID)
        )
    }

    func runIfNeeded() {
        guard defaults.bool(forKey: Self.migratedKey) == false else { return }
        copySettings()
        copyLocalImages()
        let finished = mergeICloudDriveList()
        if finished {
            defaults.set(true, forKey: Self.migratedKey)
        }
    }

    // MARK: Steps

    private func copySettings() {
        let legacyPrefix = AppIdentity.stickyToDo.settingsKeyPrefix
        for (legacyKey, value) in legacySettings {
            let key = legacyKey.hasPrefix(legacyPrefix)
                ? AppIdentity.notatka.settingsKeyPrefix + legacyKey.dropFirst(legacyPrefix.count)
                : legacyKey
            if defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
    }

    /// Images the list on this Mac (now in Notatka's keys) refers to.
    private func copyLocalImages() {
        guard FileManager.default.fileExists(atPath: legacyAttachmentsFolder.path) else { return }
        let list = UserDefaultsPersistence(defaults: defaults).load()
        AttachmentStore(directory: attachmentsFolder)
            .copyMissingFiles(for: list.tasks.flatMap(\.attachmentIDs), from: AttachmentStore(directory: legacyAttachmentsFolder))
    }

    /// False if StickyToDo's list is there but couldn't be read yet (still
    /// downloading), so the migration should run again.
    private func mergeICloudDriveList() -> Bool {
        guard defaults.bool(forKey: AppSettings.syncWithICloudKey),
              let legacyICloudFolder, let iCloudFolder,
              FileManager.default.fileExists(atPath: legacyICloudFolder.path)
        else { return true }

        let legacy = FolderPersistence(folderURL: legacyICloudFolder)
        let current = FolderPersistence(folderURL: iCloudFolder)
        defer {
            legacy.close()
            current.close()
        }

        let legacyList = legacy.load()
        let legacyFileExists = FileManager.default.fileExists(atPath: legacy.libraryURL.path)
        guard legacyList != .empty || legacyFileExists == false else { return false }

        let merged = LibraryMerger.merge(local: current.load(), remote: legacyList)
        AttachmentStore(directory: current.attachmentsURL).copyMissingFiles(
            for: merged.tasks.flatMap(\.attachmentIDs),
            from: AttachmentStore(directory: legacy.attachmentsURL)
        )
        current.save(merged)
        return true
    }
}

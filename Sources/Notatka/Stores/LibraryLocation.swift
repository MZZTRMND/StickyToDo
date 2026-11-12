import Foundation

/// Where the task list and its images live, and the storage for each place.
enum LibraryLocation: Equatable {
    /// UserDefaults and Application Support: this Mac only.
    case thisMac
    /// A Notatka folder in iCloud Drive, shared by every Mac signed in to
    /// the same Apple Account.
    case iCloudDrive(URL)

    /// iCloud Drive's Notatka folder, or nil if iCloud Drive is off. The
    /// folder is named like the Application Support one (AppIdentity), so
    /// the test build gets one of its own and can never touch the real
    /// app's list.
    static func iCloudDriveFolder(
        for identity: AppIdentity = .notatka,
        bundleID: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default
    ) -> URL? {
        let iCloudDrive = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: iCloudDrive.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return iCloudDrive.appendingPathComponent(identity.folderName(forBundleID: bundleID), isDirectory: true)
    }

    /// The place the setting asks for, or this Mac if iCloud Drive is off.
    static func current(syncWithICloud: Bool) -> LibraryLocation {
        guard syncWithICloud, let folder = iCloudDriveFolder() else { return .thisMac }
        return .iCloudDrive(folder)
    }

    func makeStorage() -> (persistence: LibraryPersistence, attachments: AttachmentStore) {
        switch self {
        case .thisMac:
            return (UserDefaultsPersistence(), AttachmentStore(savesInBackground: true))
        case .iCloudDrive(let folder):
            let persistence = FolderPersistence(folderURL: folder)
            return (persistence, AttachmentStore(directory: persistence.attachmentsURL, savesInBackground: true))
        }
    }
}

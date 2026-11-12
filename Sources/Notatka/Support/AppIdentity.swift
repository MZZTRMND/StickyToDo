import Foundation

/// The app's name and bundle id, which together name the places it keeps
/// its data: the UserDefaults domain, the "<name>." settings keys, and the
/// Application Support and iCloud Drive folders.
///
/// The app isn't sandboxed, so those folders are shared by every build. The
/// real app's folders carry just the name; any other bundle id (the test
/// build, `swift run`, tests) gets folders of its own, so it can never touch
/// the real app's data.
struct AppIdentity: Equatable {
    let name: String
    let bundleID: String

    static let notatka = AppIdentity(name: "Notatka", bundleID: "com.notatka.app")

    /// What Notatka was called before. Only StickyToDoMigration uses it, to
    /// find the data StickyToDo left on this Mac.
    static let stickyToDo = AppIdentity(name: "StickyToDo", bundleID: "com.sticky.todo")

    /// Prefix of the app's own UserDefaults keys.
    var settingsKeyPrefix: String { "\(name)." }

    func folderName(forBundleID bundleID: String?) -> String {
        if bundleID == self.bundleID { return name }
        return "\(name) (\(bundleID ?? "unbundled"))"
    }

    func applicationSupportFolder(forBundleID bundleID: String?, fileManager: FileManager = .default) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent(folderName(forBundleID: bundleID), isDirectory: true)
    }

    /// The bundle id `bundleID` corresponds to under `other`: the real app's
    /// to the real app's, the test build's to the test build's. nil for a
    /// bundle id that isn't one of this identity's builds.
    func counterpart(of bundleID: String?, in other: AppIdentity) -> String? {
        guard let bundleID else { return nil }
        if bundleID == self.bundleID { return other.bundleID }
        guard bundleID.hasPrefix(self.bundleID + ".") else { return nil }
        return other.bundleID + bundleID.dropFirst(self.bundleID.count)
    }
}

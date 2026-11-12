import SwiftUI

/// The entry point: brings over StickyToDo's data on first launch, before
/// AppDelegate reads any settings or the list, then starts the app.
@main
enum Launch {
    static func main() {
        StickyToDoMigration.forRunningBuild()?.runIfNeeded()
        NotatkaApp.main()
    }
}

struct NotatkaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

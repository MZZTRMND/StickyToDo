import SwiftUI

final class AppSettings: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                return "System"
            case .light:
                return "Light"
            case .dark:
                return "Dark"
            }
        }
    }

    static let shared = AppSettings()

    // appearance/showCheckboxes use @AppStorage since nothing subscribes to their
    // Combine publisher. launchAtLogin/showInMenuBar stay @Published because
    // AppDelegate subscribes to `settings.$property` directly, a projection
    // @AppStorage does not provide.
    @AppStorage(AppSettings.appearanceKey) var appearance: Appearance = .system
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Self.launchAtLoginKey)
        }
    }
    @Published var showInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: Self.showInMenuBarKey)
        }
    }
    @Published var taskFontSize: Double {
        didSet {
            UserDefaults.standard.set(taskFontSize, forKey: Self.taskFontSizeKey)
        }
    }
    @AppStorage(AppSettings.showCheckboxesKey) var showCheckboxes: Bool = true

    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var canManageLaunchAtLogin: Bool { supportsBundledSystemFeatures }

    private static let appearanceKey = "StickyToDo.appearance"
    private static let launchAtLoginKey = "StickyToDo.launchAtLogin"
    private static let showInMenuBarKey = "StickyToDo.showInMenuBar"
    private static let taskFontSizeKey = "StickyToDo.taskFontSize"
    private static let showCheckboxesKey = "StickyToDo.showCheckboxes"

    private init() {
        let defaults = UserDefaults.standard

        func storedBool(forKey key: String, default defaultValue: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
        }

        launchAtLogin = storedBool(forKey: Self.launchAtLoginKey, default: false)
        showInMenuBar = storedBool(forKey: Self.showInMenuBarKey, default: true)

        let storedTaskFontSize = defaults.object(forKey: Self.taskFontSizeKey) == nil
            ? 18
            : defaults.double(forKey: Self.taskFontSizeKey)
        taskFontSize = (18...32).contains(storedTaskFontSize) ? storedTaskFontSize : 18
    }

    private var supportsBundledSystemFeatures: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }
}

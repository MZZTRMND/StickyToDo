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
    /// Off makes this a menu-bar-only app: no Dock icon, no ⌘Tab entry, no
    /// menu bar menus. It and showInMenuBar can't both be off - Settings
    /// disables whichever toggle is the last way back into the app.
    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: Self.showInDockKey)
        }
    }
    @Published var taskFontSize: Double {
        didSet {
            UserDefaults.standard.set(taskFontSize, forKey: Self.taskFontSizeKey)
        }
    }
    static let defaultTaskFontSize: Double = 18
    /// The card's colors, set in the Customize window. Stored as JSON; the
    /// original style is stored as nothing at all.
    @Published var cardStyle: CardStyle {
        didSet {
            if cardStyle == .original {
                UserDefaults.standard.removeObject(forKey: Self.cardStyleKey)
            } else if let data = try? JSONEncoder().encode(cardStyle) {
                UserDefaults.standard.set(data, forKey: Self.cardStyleKey)
            }
        }
    }
    @AppStorage(AppSettings.showCheckboxesKey) var showCheckboxes: Bool = true
    /// Keeps the main window above other apps' windows. @Published because
    /// AppDelegate applies it to the window's level when it changes.
    @Published var isPinnedOnTop: Bool {
        didSet {
            UserDefaults.standard.set(isPinnedOnTop, forKey: Self.pinnedOnTopKey)
        }
    }

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
    private static let showInDockKey = "StickyToDo.showInDock"
    private static let taskFontSizeKey = "StickyToDo.taskFontSize"
    private static let showCheckboxesKey = "StickyToDo.showCheckboxes"
    private static let pinnedOnTopKey = "StickyToDo.pinnedOnTop"
    private static let cardStyleKey = "StickyToDo.cardStyle"

    private init() {
        let defaults = UserDefaults.standard

        func storedBool(forKey key: String, default defaultValue: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
        }

        launchAtLogin = storedBool(forKey: Self.launchAtLoginKey, default: false)
        showInMenuBar = storedBool(forKey: Self.showInMenuBarKey, default: true)
        showInDock = storedBool(forKey: Self.showInDockKey, default: true)
        isPinnedOnTop = storedBool(forKey: Self.pinnedOnTopKey, default: false)

        let storedTaskFontSize = defaults.object(forKey: Self.taskFontSizeKey) == nil
            ? 18
            : defaults.double(forKey: Self.taskFontSizeKey)
        taskFontSize = (18...32).contains(storedTaskFontSize) ? storedTaskFontSize : Self.defaultTaskFontSize
        cardStyle = defaults.data(forKey: Self.cardStyleKey)
            .flatMap { try? JSONDecoder().decode(CardStyle.self, from: $0) } ?? .original

        // Never start with no way back in (e.g. if the stored values were
        // edited by hand).
        if showInDock == false && showInMenuBar == false {
            showInMenuBar = true
        }
    }

    private var supportsBundledSystemFeatures: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }
}

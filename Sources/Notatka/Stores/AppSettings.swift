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
    // Combine publisher. launchAtLogin/showInDock stay @Published because
    // AppDelegate subscribes to `settings.$property` directly, a projection
    // @AppStorage does not provide.
    @AppStorage(AppSettings.appearanceKey) var appearance: Appearance = .system
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Self.launchAtLoginKey)
        }
    }
    /// Off makes this a menu-bar-only app: no Dock icon, no ⌘Tab entry, no
    /// menu bar menus. The menu bar icon is always there, so there's always
    /// a way back into the app.
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
    /// The card's width, set by dragging its edge and remembered between
    /// launches. Window geometry rather than style, so Reset All leaves it.
    @Published var cardWidth: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(cardWidth), forKey: Self.cardWidthKey)
        }
    }
    static let defaultCardWidth: CGFloat = 420
    static let cardWidthRange: ClosedRange<CGFloat> = 400...600
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

    /// Keeps the task list in iCloud Drive, shared with the user's other
    /// Macs. @Published because AppDelegate moves the list when it changes.
    @Published var syncWithICloud: Bool {
        didSet {
            UserDefaults.standard.set(syncWithICloud, forKey: Self.syncWithICloudKey)
        }
    }

    /// iCloud Drive is turned on for this Mac, so syncing is possible.
    var isICloudDriveAvailable: Bool { LibraryLocation.iCloudDriveFolder() != nil }

    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var canManageLaunchAtLogin: Bool { supportsBundledSystemFeatures }

    private static let appearanceKey = "Notatka.appearance"
    private static let launchAtLoginKey = "Notatka.launchAtLogin"
    private static let showInDockKey = "Notatka.showInDock"
    private static let taskFontSizeKey = "Notatka.taskFontSize"
    private static let showCheckboxesKey = "Notatka.showCheckboxes"
    private static let pinnedOnTopKey = "Notatka.pinnedOnTop"
    private static let cardStyleKey = "Notatka.cardStyle"
    private static let cardWidthKey = "Notatka.cardWidth"
    static let syncWithICloudKey = "Notatka.syncWithICloud"

    private init() {
        let defaults = UserDefaults.standard

        func storedBool(forKey key: String, default defaultValue: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
        }

        launchAtLogin = storedBool(forKey: Self.launchAtLoginKey, default: false)
        showInDock = storedBool(forKey: Self.showInDockKey, default: true)
        isPinnedOnTop = storedBool(forKey: Self.pinnedOnTopKey, default: false)
        syncWithICloud = storedBool(forKey: Self.syncWithICloudKey, default: false)

        let storedTaskFontSize = defaults.object(forKey: Self.taskFontSizeKey) == nil
            ? 18
            : defaults.double(forKey: Self.taskFontSizeKey)
        taskFontSize = (18...32).contains(storedTaskFontSize) ? storedTaskFontSize : Self.defaultTaskFontSize
        cardStyle = defaults.data(forKey: Self.cardStyleKey)
            .flatMap { try? JSONDecoder().decode(CardStyle.self, from: $0) } ?? .original
        let storedCardWidth = defaults.object(forKey: Self.cardWidthKey) == nil
            ? Self.defaultCardWidth
            : CGFloat(defaults.double(forKey: Self.cardWidthKey))
        cardWidth = min(max(storedCardWidth, Self.cardWidthRange.lowerBound), Self.cardWidthRange.upperBound)
    }

    private var supportsBundledSystemFeatures: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }
}

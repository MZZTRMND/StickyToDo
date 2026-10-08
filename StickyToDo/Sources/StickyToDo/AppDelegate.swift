import AppKit
import Combine
import ServiceManagement
import SwiftUI

// Borderless panel that can still become key to keep text input focused.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let store = TaskStore()
    // Owned here rather than by ContentView so quick-add (which lives in its
    // own overlay window) can see which category tab is selected.
    private let categoryUI = CategoryUIState()
    private lazy var statusItemController = StatusItemController(
        aboutAction: { [weak self] in self?.showAbout() },
        preferenceAction: { [weak self] in self?.showPreference() },
        quitAction: { [weak self] in self?.quitApp() }
    )
    private let hotKeyManager = GlobalHotKeyManager()
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var quickAddWindow: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var cancellables: Set<AnyCancellable> = []

    deinit {
        hotKeyManager.unregister()
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()
        updateStatusItemVisibility()
        bindSettingsObservers()
        applyLaunchAtLoginPreference(settings.launchAtLogin)
        createWindow()
        hotKeyManager.onTriggered = { [weak self] in self?.presentOrFocusQuickAddOverlay() }
        if hotKeyManager.register() == false {
            presentErrorAlert(
                title: "Quick Add Shortcut Unavailable",
                message: "StickyToDo couldn't register \(GlobalHotKeyManager.quickAddShortcutDisplay) as a global shortcut. Another app may already be using it."
            )
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presentQuickAddFromInAppRequest),
            name: .stickyToDoPresentQuickAddRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
    }

    /// macOS treats the first submenu of mainMenu as the Application menu,
    /// regardless of its title. Building it by hand is required here because
    /// the app supplies its own mainMenu (a plain SwiftUI App with an
    /// NSApplicationDelegateAdaptor doesn't get the standard one), and
    /// without an Application menu a .regular app has no About/Settings entry
    /// and no working Hide or Quit - those shortcuts are menu bindings, not
    /// built-in key handling.
    private func installMainMenu() {
        let appName = "StickyToDo"
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let aboutItem = appMenu.addItem(
            withTitle: "About \(appName)",
            action: #selector(showAboutFromMenu),
            keyEquivalent: ""
        )
        aboutItem.target = self

        appMenu.addItem(.separator())

        let settingsItem = appMenu.addItem(
            withTitle: "Settings\u{2026}",
            action: #selector(showPreferenceFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self

        appMenu.addItem(.separator())

        // nil target: these resolve up the responder chain to NSApplication.
        appMenu.addItem(
            withTitle: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let hideOthersItem = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )

        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAboutFromMenu() {
        showAbout()
    }

    @objc private func showPreferenceFromMenu() {
        showPreference()
    }

    /// Clicking the Dock icon should bring the widget back rather than do
    /// nothing - the window has no close button, but it can be hidden (\u{2318}H)
    /// or left behind on another Space.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func createWindow() {
        let rootHostingView = NSHostingView(rootView: AnyView(fullRootView()))
        rootHostingView.wantsLayer = true
        rootHostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView = rootHostingView

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel(panel, hostingView: rootHostingView)
        panel.minSize = NSSize(width: 350, height: 200)
        panel.maxSize = NSSize(width: 600, height: 600)
        panel.center()
        let targetSize = preferredWindowSize(fallback: panel.frame.size)
        panel.setFrame(centeredFrame(from: panel.frame, targetSize: targetSize), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel

        // SwiftUI can report a stale fitting height on the very first layout
        // pass, before NSHostingView has had a chance to lay out its content -
        // re-check on the next run loop to avoid an undersized window.
        DispatchQueue.main.async { [weak self] in
            self?.refreshWindowSizeIfNeeded(animated: false)
        }
    }

    private func configurePanel(_ panel: NSPanel, hostingView: NSView) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .normal
        // No special collectionBehavior at all - this should behave exactly
        // like a regular window (e.g. Finder): it belongs to whichever
        // single Space it's on, doesn't follow when you switch Spaces, and
        // isn't part of another app's dedicated fullscreen Space.
        panel.collectionBehavior = []
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        // Dragging is handled by DragView calling performDrag(with:) itself
        // (see WindowDragView.swift) rather than through this window-wide
        // background-drag switch, which used to be toggled on hover and
        // could get stuck disabled if a hover-exit event was ever missed.
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = hostingView
    }


    private func updateStatusItemVisibility() {
        statusItemController.setVisible(settings.showInMenuBar)
    }

    private func bindSettingsObservers() {
        settings.$showInMenuBar
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updateStatusItemVisibility()
                }
            }
            .store(in: &cancellables)

        settings.$launchAtLogin
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.applyLaunchAtLoginPreference(isEnabled)
            }
            .store(in: &cancellables)
    }

    private func applyLaunchAtLoginPreference(_ enabled: Bool) {
        guard settings.canManageLaunchAtLogin else { return }

        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled {
                try service.unregister()
            }
        } catch {
            // Keep the toggle consistent with the real system status.
            // This can fail in some unsigned/dev execution contexts.
            let syncedValue = (service.status == .enabled)
            if settings.launchAtLogin != syncedValue {
                settings.launchAtLogin = syncedValue
            }
            presentErrorAlert(
                title: "Launch at Login Unavailable",
                message: "StickyToDo couldn't change the Launch at Login setting. You can also manage this from System Settings \u{2192} General \u{2192} Login Items."
            )
        }
    }

    private func showAbout() {
        if aboutWindow == nil {
            let hostingView = NSHostingView(
                rootView: AboutView(versionText: appVersionText)
            )
            let aboutPanel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            aboutPanel.title = "About StickyToDo"
            aboutPanel.isReleasedWhenClosed = false
            aboutPanel.contentView = hostingView
            aboutWindow = aboutPanel
        }

        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPreference() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(settings)
            )
            let settingsPanel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsPanel.title = "Preference"
            settingsPanel.isReleasedWhenClosed = false
            settingsPanel.contentView = hostingView
            settingsWindow = settingsPanel
        }

        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func presentQuickAddFromInAppRequest() {
        presentOrFocusQuickAddOverlay()
    }

    @objc private func handleAppDidBecomeActive() {
        _ = store.purgeStaleCompletedTasks()
    }

    private func preferredWindowSize(fallback: NSSize) -> NSSize {
        let minWidth: CGFloat = 350
        let maxWidth: CGFloat = 600
        let minHeight: CGFloat = 200
        let maxHeight: CGFloat = 600

        let width = min(max(fallback.width, minWidth), maxWidth)

        hostingView?.layoutSubtreeIfNeeded()
        let fittingHeight = hostingView?.fittingSize.height ?? 0
        // Follow the content in both directions. This was
        // max(fallback.height, fittingHeight), which ratcheted: the window
        // could grow for a longer list but never shrink back for a shorter
        // one. Fall back to the current height only when the content hasn't
        // been laid out yet and reports nothing.
        let desiredHeight = fittingHeight > 0 ? fittingHeight : fallback.height
        let height = min(max(desiredHeight, minHeight), maxHeight)

        return NSSize(width: width, height: height)
    }

    private func refreshWindowSizeIfNeeded(animated: Bool) {
        guard let window else { return }

        let targetSize = preferredWindowSize(fallback: window.frame.size)
        guard abs(targetSize.width - window.frame.width) > 0.5 || abs(targetSize.height - window.frame.height) > 0.5 else {
            return
        }

        // Anchored at the top-left, unlike the initial centred placement:
        // re-centring on every resize would walk the window around the
        // screen as the list grows and shrinks. Growing downward from a
        // fixed corner is what a normal window does.
        let targetFrame = NSRect(
            x: window.frame.minX,
            y: window.frame.maxY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    private func centeredFrame(from currentFrame: NSRect, targetSize: NSSize) -> NSRect {
        let centerX = currentFrame.midX
        let centerY = currentFrame.midY
        return NSRect(
            x: centerX - (targetSize.width / 2),
            y: centerY - (targetSize.height / 2),
            width: targetSize.width,
            height: targetSize.height
        )
    }

    private func fullRootView() -> some View {
        RootContentView()
            .environmentObject(settings)
            .environmentObject(store)
            .environmentObject(categoryUI)
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentOrFocusQuickAddOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let quickAddWindow = self.quickAddWindow {
                quickAddWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .stickyToDoQuickAddFocusRequested, object: nil)
            } else {
                self.presentQuickAddOverlay()
            }
        }
    }

    private func presentQuickAddOverlay() {
        guard let screen = activeScreenForOverlay() else { return }

        let overlay = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        overlay.setFrame(screen.frame, display: false)
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.hidesOnDeactivate = false
        overlay.isMovableByWindowBackground = false
        overlay.level = .statusBar
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let content = QuickAddOverlayView(
            onSubmit: { [weak self] title, categoryID, image in
                guard let self else { return }
                self.store.addTask(title: title, categoryID: categoryID, attachmentImage: image)
                self.categoryUI.revealNewTask(inCategory: categoryID)
            },
            onClose: { [weak self] in
                self?.closeQuickAddOverlay()
            }
        )
        .environmentObject(store)
        .environmentObject(categoryUI)
        .preferredColorScheme(settings.preferredColorScheme)

        let host = NSHostingView(rootView: AnyView(content))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        overlay.contentView = host

        quickAddWindow = overlay
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .stickyToDoQuickAddFocusRequested, object: nil)
    }

    private func closeQuickAddOverlay() {
        quickAddWindow?.orderOut(nil)
        quickAddWindow = nil
    }

    private func activeScreenForOverlay() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return mouseScreen
        }
        return window?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private var appVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}

extension Notification.Name {
    static let stickyToDoQuickAddFocusRequested = Notification.Name("StickyToDo.QuickAddFocusRequested")
    static let stickyToDoPresentQuickAddRequested = Notification.Name("StickyToDo.PresentQuickAddRequested")
}

private struct RootContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        ContentView()
            .environmentObject(store)
            .preferredColorScheme(settings.preferredColorScheme)
    }
}

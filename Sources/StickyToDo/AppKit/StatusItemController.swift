import AppKit

/// Owns the menu-bar status item and its menu: the app's actions first
/// (new task, hide/show), then Settings and About, then Quit - the usual
/// order for a menu bar app's menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var hideItem: NSMenuItem?
    private let newTaskAction: () -> Void
    private let toggleHiddenAction: () -> Void
    private let aboutAction: () -> Void
    private let preferenceAction: () -> Void
    private let quitAction: () -> Void

    init(
        newTaskAction: @escaping () -> Void,
        toggleHiddenAction: @escaping () -> Void,
        aboutAction: @escaping () -> Void,
        preferenceAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.newTaskAction = newTaskAction
        self.toggleHiddenAction = toggleHiddenAction
        self.aboutAction = aboutAction
        self.preferenceAction = preferenceAction
        self.quitAction = quitAction
    }

    func setVisible(_ visible: Bool) {
        ensureCreated()
        statusItem?.isVisible = visible
    }

    private func ensureCreated() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "StickyToDo")
        }

        let menu = NSMenu()
        menu.delegate = self

        // The global shortcut works anywhere; showing it here makes it
        // discoverable.
        let newTaskItem = menuItem("New Task\u{2026}", action: #selector(handleNewTask), key: "n", modifiers: [.command, .option])
        menu.addItem(newTaskItem)

        // Titled in menuNeedsUpdate: "Hide StickyToDo", or "Show StickyToDo"
        // while hidden - with the Dock icon off, this is the way back.
        let hideItem = menuItem("Hide StickyToDo", action: #selector(handleToggleHidden), key: "h")
        menu.addItem(hideItem)
        self.hideItem = hideItem

        menu.addItem(.separator())

        menu.addItem(menuItem("Settings\u{2026}", action: #selector(handlePreference), key: ","))
        menu.addItem(menuItem("About StickyToDo", action: #selector(handleAbout)))

        menu.addItem(.separator())

        menu.addItem(menuItem("Quit StickyToDo", action: #selector(handleQuit), key: "q"))

        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        hideItem?.title = NSApp.isHidden ? "Show StickyToDo" : "Hide StickyToDo"
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    @objc private func handleNewTask() {
        newTaskAction()
    }

    @objc private func handleToggleHidden() {
        toggleHiddenAction()
    }

    @objc private func handleAbout() {
        aboutAction()
    }

    @objc private func handlePreference() {
        preferenceAction()
    }

    @objc private func handleQuit() {
        quitAction()
    }
}

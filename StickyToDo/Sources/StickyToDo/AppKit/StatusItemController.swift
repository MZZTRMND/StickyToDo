import AppKit

/// Owns the menu-bar status item and its About/Preference/Quit menu.
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private let aboutAction: () -> Void
    private let preferenceAction: () -> Void
    private let quitAction: () -> Void

    init(
        aboutAction: @escaping () -> Void,
        preferenceAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
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
        let aboutItem = NSMenuItem(title: "About StickyToDo", action: #selector(handleAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Preference…", action: #selector(handlePreference), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
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

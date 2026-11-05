import AppKit
import SwiftUI

/// What a task's menu can do. ContentView fills these in; the menu itself is
/// built only when it's opened (see TaskMenuBuilder).
struct TaskMenuActions {
    var toggleDone: () -> Void
    var setImportant: (Bool) -> Void
    var assignCategory: (UUID?) -> Void
    var createCategory: () -> Void
    var pasteImage: () -> Void
    /// Copies the task's only image (shown when it has exactly one).
    var copyImage: () -> Void
    var removeAllImages: () -> Void
    var edit: () -> Void
    var delete: () -> Void
}

/// Builds a task's "…" / right-click menu as an AppKit menu, at the moment
/// it's opened.
///
/// It used to be a SwiftUI Menu in every row: a real NSPopUpButton created up
/// front for each task (just in case it got clicked), which made building a
/// row ~6 ms more expensive - felt on every add, delete and tab switch. Built
/// on click instead, it also always shows the current categories and
/// clipboard, so rows don't need redrawing when those change.
enum TaskMenuBuilder {
    static func makeMenu(
        for task: TaskItem,
        categories: [TaskCategory],
        canPasteImage: Bool,
        actions: TaskMenuActions
    ) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(item(task.isDone ? "Unmark as done" : "Mark as done", symbol: "checkmark.circle", actions.toggleDone))
        menu.addItem(item(task.isImportant ? "Unmark as important" : "Mark as important", symbol: "exclamationmark.circle") {
            actions.setImportant(task.isImportant == false)
        })
        menu.addItem(.separator())

        let categoryItem = NSMenuItem(title: "Move to category", action: nil, keyEquivalent: "")
        categoryItem.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
        let categoryMenu = NSMenu()
        let noCategory = item("No category") { actions.assignCategory(nil) }
        noCategory.state = task.categoryID == nil ? .on : .off
        categoryMenu.addItem(noCategory)
        if categories.isEmpty == false {
            categoryMenu.addItem(.separator())
            for category in categories {
                let categoryOption = item(category.name) { actions.assignCategory(category.id) }
                categoryOption.state = task.categoryID == category.id ? .on : .off
                categoryMenu.addItem(categoryOption)
            }
            categoryMenu.addItem(.separator())
        }
        categoryMenu.addItem(item("Create new category", symbol: "plus", actions.createCategory))
        categoryItem.submenu = categoryMenu
        menu.addItem(categoryItem)

        if canPasteImage && task.canAddAttachment {
            menu.addItem(item("Paste Image", symbol: "photo", actions.pasteImage))
        }
        // With several images, each one has its own menu (right-click it).
        switch task.attachmentIDs.count {
        case 0:
            break
        case 1:
            menu.addItem(item("Copy Image", symbol: "doc.on.doc", actions.copyImage))
            menu.addItem(item("Remove Image", symbol: "trash", actions.removeAllImages))
        default:
            menu.addItem(item("Remove All Images", symbol: "trash", actions.removeAllImages))
        }
        menu.addItem(.separator())

        menu.addItem(item("Edit task", symbol: "pencil", actions.edit))
        menu.addItem(item("Delete task", symbol: "trash", actions.delete))
        return menu
    }

    /// The menu of one image, from right-clicking its thumbnail.
    static func makeImageMenu(open: @escaping () -> Void, copy: @escaping () -> Void, remove: @escaping () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Quick Look", symbol: "eye", open))
        menu.addItem(item("Copy Image", symbol: "doc.on.doc", copy))
        menu.addItem(.separator())
        menu.addItem(item("Remove Image", symbol: "trash", remove))
        return menu
    }

    private static func item(_ title: String, symbol: String? = nil, _ action: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, action: action)
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }
}

/// An NSMenuItem that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func run() {
        handler()
    }
}

/// Shows a menu on right-click (or Control-click) over the view it overlays,
/// and lets every other mouse event pass through to SwiftUI underneath -
/// clicks, double-clicks, drags and hover keep working as before.
struct RightClickMenuArea: NSViewRepresentable {
    let makeMenu: () -> NSMenu
    /// Wins over other areas it overlaps: an image's area inside its task's,
    /// so right-clicking the image opens the image's menu.
    var takesPrecedence = false

    func makeNSView(context: Context) -> RightClickMenuView {
        let view = RightClickMenuView()
        view.makeMenu = makeMenu
        view.takesPrecedence = takesPrecedence
        return view
    }

    func updateNSView(_ nsView: RightClickMenuView, context: Context) {
        nsView.makeMenu = makeMenu
        nsView.takesPrecedence = takesPrecedence
    }
}

final class RightClickMenuView: NSView {
    var makeMenu: (() -> NSMenu)?
    var takesPrecedence = false {
        didSet {
            if takesPrecedence {
                Self.precedenceViews.add(self)
            } else {
                Self.precedenceViews.remove(self)
            }
        }
    }

    /// The areas that take precedence. Only looked at on a right-click, so
    /// they cost nothing while the list lays out or scrolls.
    private static let precedenceViews = NSHashTable<RightClickMenuView>.weakObjects()

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp?.currentEvent, handlesMenu(for: event) else { return nil }
        return super.hitTest(point)
    }

    /// Whether this area answers `event`: a menu click, and not over an area
    /// that takes precedence (which then gets the click instead).
    func handlesMenu(for event: NSEvent) -> Bool {
        guard Self.isMenuEvent(event) else { return false }
        if takesPrecedence { return true }
        return Self.precedenceViews.allObjects.contains { other in
            guard other !== self, other.window === window, other.window != nil else { return false }
            // Its own bounds, cut to what's on screen (scrolled-away rows).
            let visible = other.bounds.intersection(other.visibleRect)
            return visible.contains(other.convert(event.locationInWindow, from: nil))
        } == false
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        makeMenu?()
    }

    static func isMenuEvent(_ event: NSEvent) -> Bool {
        switch event.type {
        case .rightMouseDown, .rightMouseUp:
            return true
        case .leftMouseDown, .leftMouseUp:
            return event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control
        default:
            return false
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Control-click.
        guard let menu = makeMenu?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

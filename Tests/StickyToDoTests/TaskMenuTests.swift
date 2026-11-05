import XCTest
import AppKit
@testable import StickyToDo

@MainActor
final class TaskMenuTests: XCTestCase {
    private var log: [String] = []

    private func makeMenu(task: TaskItem, categories: [TaskCategory] = [], canPasteImage: Bool = false) -> NSMenu {
        TaskMenuBuilder.makeMenu(
            for: task,
            categories: categories,
            canPasteImage: canPasteImage,
            actions: TaskMenuActions(
                toggleDone: { self.log.append("toggle") },
                setImportant: { self.log.append("important \($0)") },
                assignCategory: { self.log.append("category \($0?.uuidString ?? "none")") },
                createCategory: { self.log.append("create") },
                pasteImage: { self.log.append("paste") },
                copyImage: { self.log.append("copy image") },
                removeAllImages: { self.log.append("remove images") },
                edit: { self.log.append("edit") },
                delete: { self.log.append("delete") }
            )
        )
    }

    private func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
    }

    private func run(_ item: NSMenuItem?) {
        guard let item, let action = item.action else { return XCTFail("no item") }
        _ = (item.target as AnyObject?)?.perform(action, with: item)
    }

    func testPlainTaskMenu() {
        let menu = makeMenu(task: TaskItem(title: "Task"))

        XCTAssertEqual(titles(menu), [
            "Mark as done", "Mark as important", "-", "Move to category", "-", "Edit task", "Delete task",
        ])
    }

    func testMenuReflectsTaskStateClipboardAndAttachment() {
        let task = TaskItem(title: "Task", isDone: true, isImportant: true, attachmentIDs: [UUID()])
        let menu = makeMenu(task: task, canPasteImage: true)

        XCTAssertEqual(titles(menu), [
            "Unmark as done", "Unmark as important", "-", "Move to category",
            "Paste Image", "Copy Image", "Remove Image", "-", "Edit task", "Delete task",
        ])
    }

    func testCategorySubmenuChecksTheTasksCategory() {
        let work = TaskCategory(name: "Work", colorHex: "4E79A7")
        let home = TaskCategory(name: "Home", colorHex: "59A14F")
        let menu = makeMenu(task: TaskItem(title: "Task", categoryID: home.id), categories: [work, home])
        let submenu = menu.item(withTitle: "Move to category")?.submenu

        XCTAssertEqual(submenu.map(titles), ["No category", "-", "Work", "Home", "-", "Create new category"])
        XCTAssertEqual(submenu?.item(withTitle: "Home")?.state, .on)
        XCTAssertEqual(submenu?.item(withTitle: "Work")?.state, .off)
        XCTAssertEqual(submenu?.item(withTitle: "No category")?.state, .off)
    }

    func testItemsRunTheirActions() {
        let work = TaskCategory(name: "Work", colorHex: "4E79A7")
        let task = TaskItem(title: "Task")
        let menu = makeMenu(task: task, categories: [work])

        run(menu.item(withTitle: "Mark as done"))
        run(menu.item(withTitle: "Mark as important"))
        run(menu.item(withTitle: "Move to category")?.submenu?.item(withTitle: "Work"))
        run(menu.item(withTitle: "Delete task"))

        XCTAssertEqual(log, ["toggle", "important true", "category \(work.id.uuidString)", "delete"])
    }

    func testSeveralImagesOfferRemoveAllInsteadOfCopy() {
        let task = TaskItem(title: "Task", attachmentIDs: [UUID(), UUID()])
        let menu = makeMenu(task: task, canPasteImage: true)
        XCTAssertEqual(titles(menu), [
            "Mark as done", "Mark as important", "-", "Move to category",
            "Paste Image", "Remove All Images", "-", "Edit task", "Delete task",
        ])
    }

    func testAFullTaskHidesPasteImage() {
        let task = TaskItem(title: "Task", attachmentIDs: (0..<TaskItem.maxAttachments).map { _ in UUID() })
        XCTAssertFalse(titles(makeMenu(task: task, canPasteImage: true)).contains("Paste Image"))
    }

    func testImageMenu() {
        var log: [String] = []
        let menu = TaskMenuBuilder.makeImageMenu(open: { log.append("open") }, copy: { log.append("copy") }, remove: { log.append("remove") })
        XCTAssertEqual(titles(menu), ["Quick Look", "Copy Image", "-", "Remove Image"])
        for item in menu.items where item.isSeparatorItem == false {
            _ = (item.target as AnyObject?)?.perform(item.action, with: item)
        }
        XCTAssertEqual(log, ["open", "copy", "remove"])
    }
}

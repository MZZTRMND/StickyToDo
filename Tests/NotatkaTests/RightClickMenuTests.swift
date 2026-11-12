import AppKit
import SwiftUI
import XCTest
@testable import Notatka

@MainActor
final class RightClickMenuTests: XCTestCase {
    private func menu(_ title: String) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
        return menu
    }

    private func areas(in view: NSView) -> [RightClickMenuView] {
        ((view as? RightClickMenuView).map { [$0] } ?? []) + view.subviews.flatMap(areas(in:))
    }

    func testAnImageAreaWinsOverItsTasksArea() throws {
        // A "task" 300x200 with an "image" 60x60 at its top-left corner.
        let view = ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 300, height: 200)
            Color.clear.frame(width: 60, height: 60)
                .overlay { RightClickMenuArea(makeMenu: { self.menu("image") }, takesPrecedence: true) }
        }
        .overlay { RightClickMenuArea(makeMenu: { self.menu("task") }) }

        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        let all = areas(in: host)
        let task = try XCTUnwrap(all.first { $0.takesPrecedence == false })
        let image = try XCTUnwrap(all.first { $0.takesPrecedence })

        func rightClick(atTopLeftOffset x: CGFloat, _ y: CGFloat) -> NSEvent {
            // Window coordinates have their origin at the bottom-left.
            NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: x, y: 200 - y), modifierFlags: [],
                               timestamp: 0, windowNumber: window.windowNumber, context: nil,
                               eventNumber: 0, clickCount: 1, pressure: 1)!
        }

        let onImage = rightClick(atTopLeftOffset: 30, 30)
        XCTAssertTrue(image.handlesMenu(for: onImage))
        XCTAssertFalse(task.handlesMenu(for: onImage))

        let elsewhere = rightClick(atTopLeftOffset: 200, 150)
        XCTAssertTrue(task.handlesMenu(for: elsewhere))
        XCTAssertEqual(task.menu(for: elsewhere)?.items.first?.title, "task")
        XCTAssertEqual(image.menu(for: onImage)?.items.first?.title, "image")
    }

    func testOrdinaryClicksPassThrough() {
        let area = RightClickMenuView()
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
                                       windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        XCTAssertFalse(area.handlesMenu(for: click))
    }
}

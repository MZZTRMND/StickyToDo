import AppKit
import SwiftUI

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ nsView: DragView, context: Context) {}
}

final class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    // Starts the drag directly rather than relying on the window's
    // isMovableByWindowBackground switch, which ContentView used to toggle
    // off whenever the mouse hovered the task list (so a click there
    // wouldn't also drag the window). That toggle was window-wide and
    // hover-driven - if a mouseExited event was ever missed, it could stick
    // "off" and disable dragging everywhere, including here in the header.
    // Handling the drag right where it starts removes that dependency
    // entirely: this view only exists in the header, so the list needs no
    // special-casing to stay safe.
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

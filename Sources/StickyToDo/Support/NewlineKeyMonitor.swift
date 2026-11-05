import AppKit

/// While running, makes Shift+Return insert a new line at the cursor in the
/// focused text field, instead of submitting it. Return on its own still
/// submits. Used while a task is being edited, so bullet lists can be typed.
final class NewlineKeyMonitor {
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            Self.handle(event) ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        stop()
    }

    /// Return and keypad Enter.
    private static let returnKeyCodes: Set<UInt16> = [36, 76]

    private static func handle(_ event: NSEvent) -> Bool {
        guard returnKeyCodes.contains(event.keyCode),
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift,
              let textView = event.window?.firstResponder as? NSTextView,
              textView.isEditable else { return false }
        textView.insertNewlineIgnoringFieldEditor(nil)
        return true
    }
}

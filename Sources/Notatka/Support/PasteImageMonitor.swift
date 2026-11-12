import AppKit

/// Watches for ⌘V and, when active and the pasteboard holds an image, calls
/// back with it and swallows the keystroke — otherwise passes it through
/// untouched so normal text paste keeps working.
///
/// SwiftUI's `.onPasteCommand` does not reliably intercept paste on a
/// `TextField`: the field's own AppKit text editor is first responder and
/// handles ⌘V itself before SwiftUI's command-dispatch layer gets a look,
/// which is why plain text paste works there but `.onPasteCommand(of: [.image])`
/// never fires. A local key-down monitor sees the event before it's
/// dispatched to the responder chain at all, so it works regardless of who
/// the first responder is.
final class PasteImageMonitor {
    var isActive = false
    private var onImage: ((NSImage) -> Void)?
    private var monitor: Any?

    func start(onImage: @escaping (NSImage) -> Void) {
        self.onImage = onImage
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isActive else { return event }
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "v" else {
                return event
            }
            guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
                return event
            }
            self.onImage?(image)
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onImage = nil
    }

    deinit {
        stop()
    }
}

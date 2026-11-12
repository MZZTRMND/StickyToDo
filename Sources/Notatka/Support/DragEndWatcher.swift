import AppKit

/// Tells you when a drag started with SwiftUI's .onDrag is over, however it
/// ended. SwiftUI only reports drops that land on one of the app's own drop
/// targets (performDrop); a drag released outside the card, or cancelled with
/// Esc, ends silently - which left the dragged row faded and the drag cursor
/// stuck. This polls the mouse button instead, which works for every ending.
final class DragEndWatcher {
    private var timer: Timer?

    /// Calls `onEnd` once the mouse button is up, after `settleDelay` - so a
    /// drop delegate's performDrop, which runs on the same mouse-up, gets to
    /// read the drag state first.
    func start(settleDelay: TimeInterval = 0.3, onEnd: @escaping () -> Void) {
        stop()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
            self?.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: onEnd)
        }
        // .common, so it keeps firing while AppKit runs the drag session's
        // event-tracking loop.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

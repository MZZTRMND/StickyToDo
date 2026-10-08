import Foundation

/// Debounces a "show after hover delay" tooltip pattern: schedule an action
/// to run after a delay, and cancel it if the hover state changes first.
final class HoverTooltipTimer {
    private var workItem: DispatchWorkItem?

    func scheduleShow(after delay: TimeInterval = 1.0, action: @escaping () -> Void) {
        cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

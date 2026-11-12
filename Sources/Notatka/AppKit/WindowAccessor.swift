import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    final class Coordinator {
        weak var lastWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.lastWindow = window
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Check before dispatching, not inside: this runs on every SwiftUI
        // update, and enqueuing a main-queue block each time is pure churn
        // once the window is already known.
        guard nsView.window == nil || nsView.window !== context.coordinator.lastWindow else { return }
        DispatchQueue.main.async {
            if let window = nsView.window {
                guard context.coordinator.lastWindow !== window else { return }
                context.coordinator.lastWindow = window
                onWindow(window)
            }
        }
    }
}

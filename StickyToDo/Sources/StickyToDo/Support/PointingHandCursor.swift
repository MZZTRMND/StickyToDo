import SwiftUI
import AppKit

extension View {
    /// Shows the pointing-hand cursor while the pointer is over this view.
    /// SwiftUI has no cross-platform cursor API, so this wraps the small
    /// AppKit dance that was previously repeated at every clickable element.
    func pointingHandCursorOnHover() -> some View {
        onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

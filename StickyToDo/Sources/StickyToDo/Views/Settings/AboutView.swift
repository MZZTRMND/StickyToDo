import SwiftUI

struct AboutView: View {
    let versionText: String
    private let descriptionText =
        "StickyToDo is a lightweight macOS desktop widget for daily tasks. It stays on top of your desktop, lets you quickly add, complete, delete, and edit tasks, and saves everything between sessions. Designed for speed and focus with a clean, minimal UI."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("StickyToDo")
                .font(.system(size: 20, weight: .semibold))

            Text(versionText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)

            Text(descriptionText)
                .font(.system(size: 13, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 380)
    }
}

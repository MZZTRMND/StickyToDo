import SwiftUI

struct AboutView: View {
    let versionText: String
    private let descriptionText =
        "StickyToDo is a tiny floating to-do card for macOS. It keeps today's tasks in view, lets you add one from anywhere with \(GlobalHotKeyManager.quickAddShortcutDisplay), and sorts them into categories. Everything stays on your Mac: no account, no cloud."

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

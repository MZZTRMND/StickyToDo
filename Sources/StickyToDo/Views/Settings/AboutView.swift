import SwiftUI

/// The About StickyToDo window: icon, name, version and a link to the
/// project. Same layout as the About window in Cubby.
struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .padding(.bottom, 12)
            Text("StickyToDo")
                .font(.title2.weight(.semibold))
            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text("A tiny floating to-do card for your desktop.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            Link("github.com/MZZTRMND/StickyToDo", destination: URL(string: "https://github.com/MZZTRMND/StickyToDo")!)
                .font(.callout)
                .padding(.top, 10)
        }
        .padding(.horizontal, 40)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(width: 300)
        .fixedSize()
    }
}

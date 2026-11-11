import SwiftUI

/// StickyToDo's settings, laid out like Cubby's: short groups - how the card
/// behaves, how the app looks and where it shows up, iCloud sync, and a way
/// into the Customize window - with explanations in the group footers.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .disabled(settings.canManageLaunchAtLogin == false)
                Toggle("Keep on top of other windows", isOn: $settings.isPinnedOnTop)
                LabeledContent("Quick add") {
                    Text(GlobalHotKeyManager.quickAddShortcutDisplay)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    footnote("Press \(GlobalHotKeyManager.quickAddShortcutDisplay) in any app to add a task. Keep on top is the same as Pin on Top in the card's right-click menu.")
                    if settings.canManageLaunchAtLogin == false {
                        footnote("Launch at login is available only when StickyToDo runs as a packaged app.")
                    }
                }
            }

            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                Toggle("Show checkboxes", isOn: $settings.showCheckboxes)
                Toggle("Show in Dock", isOn: $settings.showInDock)
            } footer: {
                footnote("StickyToDo is always in the menu bar.")
            }

            Section {
                Toggle("Sync with iCloud Drive", isOn: $settings.syncWithICloud)
                    .disabled(settings.isICloudDriveAvailable == false)
            } footer: {
                if settings.isICloudDriveAvailable {
                    footnote("Keeps your tasks in iCloud Drive \u{203A} \(LibraryLocation.iCloudDriveFolder()?.lastPathComponent ?? "StickyToDo"), so every Mac signed in to your Apple Account shows the same list.")
                } else {
                    footnote("Turn on iCloud Drive in System Settings to sync your tasks between Macs.")
                }
            }

            Section {
                HStack(spacing: 14) {
                    MiniCard(style: settings.cardStyle)
                        .frame(width: 58, height: 50)
                        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Card Style")
                        Text(settings.cardStyle.paletteName)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Customize\u{2026}") {
                        NotificationCenter.default.post(name: .stickyToDoShowCustomizeRequested, object: nil)
                    }
                }
            } header: {
                Text("Look")
            } footer: {
                footnote("Colors, text size and spacing.")
            }
        }
        .formStyle(.grouped)
        // Everything fits without scrolling, so the window can size itself to
        // the content (see AppDelegate.showPreference) instead of a guess.
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

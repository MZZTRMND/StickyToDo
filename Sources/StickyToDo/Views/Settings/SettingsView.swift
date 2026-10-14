import SwiftUI

/// A grouped Form, the System Settings layout: rounded sections, labels on
/// the left, controls on the right, switches for on/off settings, and
/// explanations in section footers rather than between the controls.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            generalSection
            windowSection
            appearanceSection
            lookSection
            shortcutSection
        }
        .formStyle(.grouped)
        // Everything fits without scrolling, so the window can size itself to
        // the content (see AppDelegate.showPreference) instead of a guess.
        .scrollDisabled(true)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var generalSection: some View {
        Section {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .disabled(settings.canManageLaunchAtLogin == false)

            // Whichever of these is the last way back into the app stays on.
            Toggle("Show in Dock", isOn: $settings.showInDock)
                .disabled(settings.showInMenuBar == false)

            Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
                .disabled(settings.showInDock == false)
        } header: {
            Text("General")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if settings.showInDock == false || settings.showInMenuBar == false {
                    footnote("StickyToDo needs either a Dock icon or a menu bar icon, so one of them stays on.")
                }
                if settings.canManageLaunchAtLogin == false {
                    footnote("Launch at login is available only when StickyToDo runs as a packaged app.")
                }
            }
        }
    }

    private var windowSection: some View {
        Section {
            Toggle("Keep on top of other windows", isOn: $settings.isPinnedOnTop)
        } header: {
            Text("Window")
        } footer: {
            footnote("Same as Pin on Top in the card's right-click menu.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Show checkboxes", isOn: $settings.showCheckboxes)
        }
    }

    /// The card's current look, with the way into the Customize window - the
    /// same row as Look in Cubby's Settings.
    private var lookSection: some View {
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

    private var shortcutSection: some View {
        Section("Keyboard Shortcut") {
            LabeledContent("Quick add") {
                Text(GlobalHotKeyManager.quickAddShortcutDisplay)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

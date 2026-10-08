import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            appearanceSection

            sectionDivider

            generalSection

            sectionDivider

            tasksSection

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: 400, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Appearance")

            HStack(alignment: .center, spacing: 16) {
                Text("Theme")
                    .frame(width: 80, alignment: .leading)

                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("General")

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .toggleStyle(.checkbox)
                .disabled(settings.canManageLaunchAtLogin == false)

            Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
                .toggleStyle(.checkbox)

            if settings.canManageLaunchAtLogin == false {
                helperText("Launch at Login is available only when StickyToDo runs as a packaged .app.")
                    .padding(.top, 2)
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tasks")

            Toggle("Show Checkboxes", isOn: $settings.showCheckboxes)
                .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Task Font Size")
                    Spacer()
                    Text("\(Int(settings.taskFontSize))")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settings.taskFontSize, in: 18...32, step: 1)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 18)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

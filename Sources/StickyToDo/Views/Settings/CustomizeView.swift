import SwiftUI

/// The Customize window: the card's colors and text size, in tabs. There's no
/// preview pane - every change applies to the real card right away. Layout and
/// controls follow the Customize window in Cubby.
struct CustomizeView: View {
    @EnvironmentObject private var settings: AppSettings
    let onDone: () -> Void

    @State private var tab = Tab.color

    enum Tab: String, CaseIterable, Identifiable {
        case color, size
        var id: Self { self }
        var title: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .color: "paintpalette"
            case .size: "textformat.size"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customize StickyToDo")
                        .font(.title3.weight(.semibold))
                    Text(settings.cardStyle.paletteName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: settings.cardStyle.paletteName)
                }
                TabBar(selection: $tab)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Group {
                switch tab {
                case .color: ColorTab(style: $settings.cardStyle)
                case .size: SizeTab(style: $settings.cardStyle, taskFontSize: $settings.taskFontSize)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()
            HStack {
                Button("Reset All", role: .destructive) {
                    withAnimation(.snappy) {
                        settings.cardStyle = .original
                        settings.taskFontSize = AppSettings.defaultTaskFontSize
                    }
                }
                .disabled(settings.cardStyle == .original && settings.taskFontSize == AppSettings.defaultTaskFontSize)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 380, height: 500)
        .background(.background)
    }
}

/// Equal tabs with an icon over the title, like a toolbar.
private struct TabBar: View {
    @Binding var selection: CustomizeView.Tab
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CustomizeView.Tab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 15, weight: .medium))
                            .frame(height: 18)
                        Text(tab.title)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.tint.opacity(0.12))
                                .matchedGeometryEffect(id: "tab", in: highlight)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

// MARK: Color

private struct ColorTab: View {
    @Binding var style: CardStyle

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(CardStyle.Palette.all) { palette in
                        PaletteCard(palette: palette, isSelected: style.palette == palette) {
                            withAnimation(.snappy) { style.apply(palette) }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Palette")
            } footer: {
                ResetFooter(note: "Each palette has a light and a dark version, following the appearance.",
                            isDisabled: style.isOriginalColor) {
                    style.resetColor()
                }
            }
        }
    }
}

/// A palette as a little card with its name.
private struct PaletteCard: View {
    let palette: CardStyle.Palette
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MiniCard(style: CardStyle(paletteID: palette.id))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.fill.quaternary.opacity(isHovered ? 1.6 : 1),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                    }
                Text(palette.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

/// A small, static drawing of the card in a style - in the palette's light
/// or dark version for the current appearance: a checked task and two lines
/// of "text", inked the way the real card would be. Also used by Settings.
struct MiniCard: View {
    let style: CardStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = style.colors(for: colorScheme)
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(colors.background)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.separator)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colors.accent ?? Theme.primaryText)
                            .frame(width: 7, height: 7)
                        Capsule().fill(Theme.tertiaryText).frame(width: 18, height: 3)
                    }
                    HStack(spacing: 4) {
                        Circle().strokeBorder(Theme.tertiaryText, lineWidth: 1).frame(width: 7, height: 7)
                        Capsule().fill(Theme.secondaryText).frame(width: 22, height: 3)
                    }
                }
                .padding(7)
                .environment(\.colorScheme, colors.inkScheme ?? colorScheme)
            }
            .frame(width: 50, height: 40)
    }
}

// MARK: Size

private struct SizeTab: View {
    @Binding var style: CardStyle
    @Binding var taskFontSize: Double

    var body: some View {
        Form {
            Section("Text") {
                StyleSlider(title: "Task text size", value: $taskFontSize, in: 18...32, step: 1)
            }
            Section {
                Picker("Spacing", selection: $style.density) {
                    ForEach(CardStyle.Density.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Layout")
            } footer: {
                ResetFooter(note: "Drag the card's edge to change its width.",
                            isDisabled: taskFontSize == AppSettings.defaultTaskFontSize && style.isOriginalSize) {
                    taskFontSize = AppSettings.defaultTaskFontSize
                    style.resetSize()
                }
            }
        }
    }
}

// MARK: Controls

/// A title and value over a full-width slider.
private struct StyleSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    init(title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.rounded())) pt")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: value))
            }
            Slider(value: $value, in: range, step: step) { Text(title) }
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

/// A short note and a Reset button under a tab's last section.
private struct ResetFooter: View {
    let note: String
    let isDisabled: Bool
    let reset: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Reset") { withAnimation(.snappy) { reset() } }
                .controlSize(.small)
                .disabled(isDisabled)
        }
    }
}

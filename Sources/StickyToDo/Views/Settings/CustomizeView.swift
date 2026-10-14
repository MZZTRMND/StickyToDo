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
                case .size: SizeTab(taskFontSize: $settings.taskFontSize)
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
        .frame(width: 380, height: 700)
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

    private static let cardSwatches: [RGBA] = [
        RGBA(hex: 0xFFF1A8), RGBA(hex: 0xD9F4E4), RGBA(hex: 0xDDEBFF), RGBA(hex: 0xE9E2FF),
        RGBA(hex: 0xFFE1E7), RGBA(hex: 0xF4EFE6), RGBA(hex: 0x2C2C2F),
    ]
    private static let accentSwatches: [RGBA] = [
        RGBA(0.98, 0.36, 0.34), RGBA(0.98, 0.60, 0.28), RGBA(hex: 0xD99A00), RGBA(0.30, 0.76, 0.48),
        RGBA(0.27, 0.52, 0.96), RGBA(0.58, 0.48, 0.94), RGBA(0.22, 0.22, 0.24),
    ]

    var body: some View {
        Form {
            Section("Palette") {
                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(CardStyle.Palette.all) { palette in
                        PaletteCard(palette: palette, isSelected: style.uses(palette)) {
                            withAnimation(.snappy) { style.apply(palette) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                SwatchPicker(title: "Card", swatches: Self.cardSwatches, selection: $style.cardColor)
                SwatchPicker(title: "Accent", swatches: Self.accentSwatches, selection: $style.accentColor)
            } header: {
                Text("Colors")
            } footer: {
                ResetFooter(note: "Accent colors the selected tab and checked tasks. Text on a colored card stays readable, like ink on a sticky note.",
                            isDisabled: style.isOriginalColor) {
                    style = .original
                }
            }
        }
    }
}

/// A palette as a little card with its name; picking it sets the card and
/// accent colors.
private struct PaletteCard: View {
    let palette: CardStyle.Palette
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MiniCard(style: CardStyle(cardColor: palette.card, accentColor: palette.accent))
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

/// A small, static drawing of the card in a style: a checked task and two
/// lines of "text", inked the way the real card would be.
private struct MiniCard: View {
    let style: CardStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(style.background)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.separator)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(style.accentColor?.color ?? Theme.primaryText)
                            .frame(width: 7, height: 7)
                        Capsule().fill(Theme.tertiaryText).frame(width: 18, height: 3)
                    }
                    HStack(spacing: 4) {
                        Circle().strokeBorder(Theme.tertiaryText, lineWidth: 1).frame(width: 7, height: 7)
                        Capsule().fill(Theme.secondaryText).frame(width: 22, height: 3)
                    }
                }
                .padding(7)
            }
            .frame(width: 50, height: 40)
            .environment(\.colorScheme, style.inkScheme ?? colorScheme)
    }
}

/// A title over a row of color dots: the system color first, a few colors,
/// and the system color picker for anything else.
private struct SwatchPicker: View {
    let title: String
    let swatches: [RGBA]
    @Binding var selection: RGBA?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                Text(selection?.hexString ?? "System")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                Dot(isSelected: selection == nil) {
                    // Half light, half dark: it follows the appearance.
                    Circle().fill(LinearGradient(stops: [.init(color: Color(white: 0.92), location: 0.5),
                                                         .init(color: Color(white: 0.28), location: 0.5)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                } action: {
                    selection = nil
                }
                .help("System color")
                ForEach(swatches, id: \.self) { swatch in
                    Dot(isSelected: selection == swatch) {
                        Circle().fill(swatch.color.gradient)
                    } action: {
                        selection = swatch
                    }
                }
                Spacer(minLength: 0)
                ColorPicker(title, selection: Binding(
                    get: { selection?.color ?? .gray },
                    set: { selection = RGBA($0) }
                ), supportsOpacity: false)
                .labelsHidden()
                .help("Any color")
            }
        }
        .padding(.vertical, 2)
    }

    private struct Dot<Fill: View>: View {
        let isSelected: Bool
        @ViewBuilder let fill: Fill
        let action: () -> Void
        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                fill
                    .frame(width: 20, height: 20)
                    .overlay { Circle().strokeBorder(.separator) }
                    .padding(2.5)
                    .overlay {
                        Circle().strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                    }
                    .scaleEffect(isHovered && !isSelected ? 1.1 : 1)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .animation(.snappy(duration: 0.2), value: isHovered)
            .animation(.snappy(duration: 0.2), value: isSelected)
        }
    }
}

// MARK: Size

private struct SizeTab: View {
    @Binding var taskFontSize: Double

    var body: some View {
        Form {
            Section {
                StyleSlider(title: "Task text size", value: $taskFontSize, in: 18...32, step: 1)
            } header: {
                Text("Text")
            } footer: {
                ResetFooter(note: "The size of task titles on the card.",
                            isDisabled: taskFontSize == AppSettings.defaultTaskFontSize) {
                    taskFontSize = AppSettings.defaultTaskFontSize
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

import SwiftUI
import AppKit

/// Native macOS semantic colors. Unlike the old fixed hex values, every
/// token here resolves automatically for the current appearance - there's no
/// need for a `for scheme:` parameter, and no `colorScheme == .dark ? … : …`
/// branching at call sites.
enum Theme {
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    static let placeholderText = Color(nsColor: .placeholderTextColor)

    static let cardBackground = Color(nsColor: .windowBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    /// A faint tint of the primary text color, used for generic hover
    /// highlights - labelColor already adapts per appearance, so a single
    /// fixed opacity reads correctly in both light and dark mode.
    static let hoverFill = Color(nsColor: .labelColor).opacity(0.05)

    static let accent = Color(nsColor: .controlAccentColor)
    static let importantRed = Color(nsColor: .systemRed)

    static let categoryPalette: [String] = [
        "4E79A7",
        "59A14F",
        "E15759",
        "F28E2B",
        "76B7B2",
        "B07AA1",
        "EDC948",
        "9C755F"
    ]

    static func color(fromHex hex: String) -> Color {
        Color(nsColor: nsColor(fromHex: hex) ?? .systemBlue)
    }

    /// Shadows aren't really a "text/control" semantic token macOS exposes
    /// directly, and the two intensities here were deliberately tuned by eye
    /// against each background, so this one stays scheme-aware.
    static func shadow(for scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.22 : 0.10)
    }

    private static func nsColor(fromHex hex: String) -> NSColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }
}

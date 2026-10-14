import SwiftUI

/// How the card looks, set in the Customize window. Stored as JSON in
/// AppSettings; nil colors mean "use the system color", so the default style
/// is exactly the card as it looked before Customize existed.
struct CardStyle: Codable, Equatable {
    /// The card's background; nil is the system window color, which follows
    /// light and dark mode.
    var cardColor: RGBA?
    /// The selected category tab and checked tasks; nil keeps the system
    /// accent for the tab and the text color for checked tasks.
    var accentColor: RGBA?

    static let original = CardStyle()

    var background: Color { cardColor?.color ?? Theme.cardBackground }

    /// Like ink on a sticky note: a colored card keeps text readable on it
    /// whatever the system appearance - dark text on light cards, light text
    /// on dark ones. nil (no card color) follows the system as before.
    var inkScheme: ColorScheme? {
        guard let cardColor else { return nil }
        // ~0.18 is where black and white text have equal contrast on the card.
        return cardColor.luminance > 0.18 ? .light : .dark
    }
}

extension CardStyle {
    /// Ready-made card and accent pairs.
    struct Palette: Identifiable {
        let name: String
        let card: RGBA?
        let accent: RGBA?
        var id: String { name }

        static let all: [Palette] = [
            Palette(name: "Original", card: nil, accent: nil),
            Palette(name: "Classic", card: RGBA(hex: 0xFFF1A8), accent: RGBA(hex: 0xD99A00)),
            Palette(name: "Mint", card: RGBA(hex: 0xD9F4E4), accent: RGBA(hex: 0x2FA36B)),
            Palette(name: "Sky", card: RGBA(hex: 0xDDEBFF), accent: RGBA(hex: 0x3478F6)),
            Palette(name: "Lavender", card: RGBA(hex: 0xE9E2FF), accent: RGBA(hex: 0x7C5CE0)),
            Palette(name: "Blush", card: RGBA(hex: 0xFFE1E7), accent: RGBA(hex: 0xE0527A)),
            Palette(name: "Paper", card: RGBA(hex: 0xF4EFE6), accent: RGBA(hex: 0x9A7547)),
            Palette(name: "Graphite", card: RGBA(hex: 0x2C2C2F), accent: RGBA(hex: 0xF5A623)),
        ]
    }

    func uses(_ palette: Palette) -> Bool {
        cardColor == palette.card && accentColor == palette.accent
    }

    mutating func apply(_ palette: Palette) {
        cardColor = palette.card
        accentColor = palette.accent
    }

    var paletteName: String { Palette.all.first(where: uses)?.name ?? "Custom" }

    var isOriginalColor: Bool { uses(Palette.all[0]) }
}

/// A color that can be saved: sRGB components.
struct RGBA: Codable, Equatable, Hashable {
    var red, green, blue: Double
    var alpha = 1.0

    init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        (self.red, self.green, self.blue, self.alpha) = (red, green, blue, alpha)
    }

    init(hex: UInt32) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .gray
        self.init(ns.redComponent, ns.greenComponent, ns.blueComponent, ns.alphaComponent)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    /// Relative luminance (WCAG), 0 for black to 1 for white.
    var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}

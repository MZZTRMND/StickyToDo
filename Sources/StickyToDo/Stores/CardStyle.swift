import SwiftUI

/// How the card looks, set in the Customize window: one of the ready-made
/// palettes, and the task spacing. Stored as JSON in AppSettings; the
/// original style is stored as nothing, so the default card is exactly as
/// it looked before Customize existed.
struct CardStyle: Codable, Equatable {
    /// Palette.id of the chosen palette.
    var paletteID = Palette.original.id
    /// How much room each task gets.
    var density = Density.regular

    static let original = CardStyle()

    init(paletteID: String = Palette.original.id, density: Density = .regular) {
        self.paletteID = paletteID
        self.density = density
    }

    /// Anything missing or unknown in a stored copy falls back to the
    /// default, so new settings never wipe old ones - and a style stored by
    /// an older build (free card/accent colors) comes back as Original.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedID = (try? container.decodeIfPresent(String.self, forKey: .paletteID)) ?? nil
        paletteID = Palette.all.contains { $0.id == storedID } ? storedID! : Palette.original.id
        density = (try? container.decodeIfPresent(Density.self, forKey: .density)) ?? .regular
    }

    var palette: Palette { Palette.all.first { $0.id == paletteID } ?? .original }
    var paletteName: String { palette.name }
    var isOriginalColor: Bool { paletteID == Palette.original.id }
    var isOriginalSize: Bool { density == .regular }

    mutating func apply(_ palette: Palette) { paletteID = palette.id }

    /// Back to Original colors, keeping the spacing.
    mutating func resetColor() { paletteID = Palette.original.id }

    /// Back to the original spacing, keeping the palette.
    mutating func resetSize() { density = .regular }

    /// The card's colors for the system appearance it's shown in.
    func colors(for appearance: ColorScheme) -> CardColors {
        CardColors(variant: palette.variant(for: appearance))
    }
}

// MARK: Palettes

extension CardStyle {
    /// A ready-made look with a light-mode and a dark-mode version, so a
    /// colored card stays at home in either appearance.
    struct Palette: Identifiable, Equatable {
        let id: String
        let name: String
        /// nil for Original: the system colors, as before Customize.
        let light: Variant?
        let dark: Variant?

        func variant(for appearance: ColorScheme) -> Variant? {
            appearance == .dark ? dark : light
        }

        static let original = Palette(id: "original", name: "Original", light: nil, dark: nil)

        static let all: [Palette] = [
            original,
            Palette(id: "classic", name: "Classic",
                    light: Variant(card: 0xFFF1A8, accent: 0xD99A00),
                    dark: Variant(card: 0x3A3419, accent: 0xF2C14E)),
            Palette(id: "mint", name: "Mint",
                    light: Variant(card: 0xD9F4E4, accent: 0x2FA36B),
                    dark: Variant(card: 0x1D3328, accent: 0x4CCF8E)),
            Palette(id: "sky", name: "Sky",
                    light: Variant(card: 0xDDEBFF, accent: 0x3478F6),
                    dark: Variant(card: 0x1B2940, accent: 0x5E9EFF)),
            Palette(id: "lavender", name: "Lavender",
                    light: Variant(card: 0xE9E2FF, accent: 0x7C5CE0),
                    dark: Variant(card: 0x29233F, accent: 0xA58CFF)),
            Palette(id: "blush", name: "Blush",
                    light: Variant(card: 0xFFE1E7, accent: 0xE0527A),
                    dark: Variant(card: 0x3C2128, accent: 0xFF7D9E)),
            Palette(id: "paper", name: "Paper",
                    light: Variant(card: 0xF4EFE6, accent: 0x9A7547),
                    dark: Variant(card: 0x322F29, accent: 0xD4AA70)),
            Palette(id: "graphite", name: "Graphite",
                    light: Variant(card: 0x2C2C2F, accent: 0xF5A623),
                    dark: Variant(card: 0x1F1F21, accent: 0xF5A623)),
        ]
    }

    /// One appearance of a palette: the card and its accent (the selected
    /// tab and checked tasks).
    struct Variant: Equatable {
        let card: RGBA
        let accent: RGBA

        init(card: UInt32, accent: UInt32) {
            self.card = RGBA(hex: card)
            self.accent = RGBA(hex: accent)
        }
    }

    enum Density: String, Codable, CaseIterable, Identifiable {
        case compact, regular, airy
        var id: Self { self }
        var title: String { rawValue.capitalized }

        /// Space above and below a task's content. Regular is the original 12.
        var rowVerticalPadding: CGFloat {
            switch self {
            case .compact: 7
            case .regular: 12
            case .airy: 17
            }
        }

        /// A short task's height. Regular is the original 48.
        var rowMinimumHeight: CGFloat {
            switch self {
            case .compact: 38
            case .regular: 48
            case .airy: 58
            }
        }

        /// The gap between tasks. Regular is the original 4.
        var rowSpacing: CGFloat {
            switch self {
            case .compact: 2
            case .regular: 4
            case .airy: 8
            }
        }
    }
}

// MARK: Resolved colors

/// A palette resolved for one appearance. ContentView works this out from
/// the real appearance and hands it to the card's subviews through the
/// environment, because inside the card the color scheme is the ink's
/// (Graphite forces light text even in light mode), not the system's.
struct CardColors: Equatable {
    /// nil when the palette is Original and the system colors apply.
    let variant: CardStyle.Variant?

    var background: Color { variant?.card.color ?? Theme.cardBackground }
    /// nil keeps the system accent for the tab and the text color for checks.
    var accent: Color? { variant?.accent.color }

    /// Text on the card stays readable: dark ink on light cards, light on
    /// dark ones. nil follows the system, for Original.
    var inkScheme: ColorScheme? {
        guard let card = variant?.card else { return nil }
        // ~0.18 is where black and white text have equal contrast on the card.
        return card.luminance > 0.18 ? .light : .dark
    }
}

private struct CardColorsKey: EnvironmentKey {
    static let defaultValue = CardColors(variant: nil)
}

extension EnvironmentValues {
    var cardColors: CardColors {
        get { self[CardColorsKey.self] }
        set { self[CardColorsKey.self] = newValue }
    }
}

/// A color as sRGB components.
struct RGBA: Equatable, Hashable {
    var red, green, blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        (self.red, self.green, self.blue) = (red, green, blue)
    }

    init(hex: UInt32) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    /// Relative luminance (WCAG), 0 for black to 1 for white.
    var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

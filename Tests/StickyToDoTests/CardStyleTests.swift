import XCTest
@testable import StickyToDo

final class CardStyleTests: XCTestCase {
    func testOriginalFollowsTheSystem() {
        XCTAssertNil(CardStyle.original.inkScheme)
        XCTAssertEqual(CardStyle.original.paletteName, "Original")
    }

    func testLightCardsGetDarkInk() {
        for name in ["Classic", "Mint", "Sky", "Lavender", "Blush", "Paper"] {
            var style = CardStyle.original
            style.apply(palette(name))
            XCTAssertEqual(style.inkScheme, .light, "\(name) should keep dark text")
        }
    }

    func testGraphiteGetsLightInk() {
        var style = CardStyle.original
        style.apply(palette("Graphite"))
        XCTAssertEqual(style.inkScheme, .dark)
    }

    func testInkFollowsWhicheverTextHasMoreContrast() {
        // Deep blue, luminance ~0.13: white text contrasts more (6.2 vs 3.6).
        XCTAssertEqual(CardStyle(cardColor: RGBA(hex: 0x1F5FD1), accentColor: nil).inkScheme, .dark)
        // Mid blue, luminance ~0.21: black text contrasts more (5.2 vs 4.1).
        XCTAssertEqual(CardStyle(cardColor: RGBA(hex: 0x3478F6), accentColor: nil).inkScheme, .light)
    }

    func testPaletteNameIsCustomWhenEdited() {
        var style = CardStyle.original
        style.apply(palette("Mint"))
        XCTAssertEqual(style.paletteName, "Mint")
        style.accentColor = RGBA(hex: 0x123456)
        XCTAssertEqual(style.paletteName, "Custom")
    }

    func testRoundTripsThroughJSON() throws {
        var style = CardStyle.original
        style.apply(palette("Lavender"))
        let decoded = try JSONDecoder().decode(CardStyle.self, from: JSONEncoder().encode(style))
        XCTAssertEqual(decoded, style)
    }

    private func palette(_ name: String) -> CardStyle.Palette {
        CardStyle.Palette.all.first { $0.name == name }!
    }
}

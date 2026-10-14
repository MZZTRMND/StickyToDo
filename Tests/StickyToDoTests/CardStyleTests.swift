import XCTest
import SwiftUI
@testable import StickyToDo

final class CardStyleTests: XCTestCase {
    func testOriginalFollowsTheSystem() {
        for appearance in [ColorScheme.light, .dark] {
            let colors = CardStyle.original.colors(for: appearance)
            XCTAssertNil(colors.variant)
            XCTAssertNil(colors.inkScheme)
        }
        XCTAssertEqual(CardStyle.original.paletteName, "Original")
    }

    func testEveryColoredPaletteHasALightAndADarkVersion() {
        for palette in CardStyle.Palette.all where palette != .original {
            XCTAssertNotNil(palette.light, "\(palette.name) needs a light version")
            XCTAssertNotNil(palette.dark, "\(palette.name) needs a dark version")
        }
    }

    func testColoredPalettesMatchTheAppearanceExceptGraphite() {
        // In light mode the cards are light (dark text); in dark mode they're
        // deep tints (light text) - so the card always sits at home.
        for palette in CardStyle.Palette.all where palette != .original && palette.id != "graphite" {
            let style = CardStyle(paletteID: palette.id)
            XCTAssertEqual(style.colors(for: .light).inkScheme, .light, "\(palette.name) in light mode")
            XCTAssertEqual(style.colors(for: .dark).inkScheme, .dark, "\(palette.name) in dark mode")
        }
    }

    func testGraphiteIsADarkCardInBothAppearances() {
        let style = CardStyle(paletteID: "graphite")
        XCTAssertEqual(style.colors(for: .light).inkScheme, .dark)
        XCTAssertEqual(style.colors(for: .dark).inkScheme, .dark)
    }

    func testRoundTripsThroughJSON() throws {
        let style = CardStyle(paletteID: "lavender", density: .compact)
        let decoded = try JSONDecoder().decode(CardStyle.self, from: JSONEncoder().encode(style))
        XCTAssertEqual(decoded, style)
        XCTAssertEqual(decoded.paletteName, "Lavender")
    }

    func testOldFreeColorStyleFallsBackToOriginal() throws {
        // Stored by the first Customize builds, before palettes-only.
        let json = #"{"cardColor":{"red":1,"green":0.945,"blue":0.659,"alpha":1},"density":"airy"}"#
        let style = try JSONDecoder().decode(CardStyle.self, from: Data(json.utf8))
        XCTAssertTrue(style.isOriginalColor)
        XCTAssertEqual(style.density, .airy)
    }

    func testUnknownPaletteFallsBackToOriginal() throws {
        let style = try JSONDecoder().decode(CardStyle.self, from: Data(#"{"paletteID":"neon"}"#.utf8))
        XCTAssertEqual(style, .original)
    }

    func testResetColorKeepsSizeAndResetSizeKeepsColor() {
        let style = CardStyle(paletteID: "mint", density: .airy)

        var colorReset = style
        colorReset.resetColor()
        XCTAssertTrue(colorReset.isOriginalColor)
        XCTAssertEqual(colorReset.density, .airy)

        var sizeReset = style
        sizeReset.resetSize()
        XCTAssertTrue(sizeReset.isOriginalSize)
        XCTAssertEqual(sizeReset.paletteName, "Mint")
    }
}

import Foundation
import XCTest
@testable import Notatka

final class TaskTitleFormatTests: XCTestCase {
    func testPlainTitleIsOneUnformattedLine() {
        let lines = TaskTitleFormat.lines(from: "Buy milk")
        XCTAssertEqual(lines, [.init(isBullet: false, text: AttributedString("Buy milk"))])
    }

    func testBoldAndItalicMarksBecomeFormatting() {
        let text = TaskTitleFormat.inline("Call **Anna** about *rent*")
        XCTAssertEqual(String(text.characters), "Call Anna about rent")

        let bold = text.runs.first { String(text[$0.range].characters) == "Anna" }
        XCTAssertEqual(bold?.inlinePresentationIntent, .stronglyEmphasized)
        let italic = text.runs.first { String(text[$0.range].characters) == "rent" }
        XCTAssertEqual(italic?.inlinePresentationIntent, .emphasized)
    }

    func testBulletLines() {
        let lines = TaskTitleFormat.lines(from: "Groceries\n- milk\n* **eggs**\n  • bread")
        XCTAssertEqual(lines.map(\.isBullet), [false, true, true, true])
        XCTAssertEqual(lines.map { String($0.text.characters) }, ["Groceries", "milk", "eggs", "bread"])
    }

    func testItalicAtLineStartIsNotABullet() {
        let lines = TaskTitleFormat.lines(from: "*soon* call back")
        XCTAssertEqual(lines.first?.isBullet, false)
        XCTAssertEqual(String(lines[0].text.characters), "soon call back")
    }

    func testDashWithoutSpaceIsNotABullet() {
        XCTAssertEqual(TaskTitleFormat.lines(from: "-5 degrees").first?.isBullet, false)
    }

    func testUnclosedMarkStaysAsTyped() {
        XCTAssertEqual(String(TaskTitleFormat.inline("2 * 3 = 6").characters), "2 * 3 = 6")
        XCTAssertEqual(String(TaskTitleFormat.inline("**half").characters), "**half")
    }

    func testLinksKeepTheirTextButAreNotLinks() {
        let text = TaskTitleFormat.inline("see [docs](https://example.com) *now*")
        XCTAssertEqual(String(text.characters), "see docs now")
        XCTAssertTrue(text.runs.allSatisfy { $0.link == nil })
    }

    func testEmptyLineKeepsItsPlace() {
        let lines = TaskTitleFormat.lines(from: "a\n\nb")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(String(lines[1].text.characters), " ")
    }
}

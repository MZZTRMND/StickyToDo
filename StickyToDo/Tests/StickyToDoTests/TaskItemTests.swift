import XCTest
@testable import StickyToDo

final class TaskItemTests: XCTestCase {
    func testDecodingLegacyPayloadFillsInMissingFieldsWithDefaults() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let legacyJSON = """
        {
            "id": "\(id.uuidString)",
            "title": "Legacy task",
            "isDone": true,
            "createdAt": \(createdAt.timeIntervalSinceReferenceDate)
        }
        """
        let data = Data(legacyJSON.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let task = try decoder.decode(TaskItem.self, from: data)

        XCTAssertEqual(task.id, id)
        XCTAssertEqual(task.title, "Legacy task")
        XCTAssertTrue(task.isDone)
        XCTAssertFalse(task.isImportant)
        XCTAssertNil(task.categoryID)
        XCTAssertNil(task.doneAt)
        XCTAssertNil(task.attachmentID)
    }

    func testEncodeDecodeRoundTripPreservesAllFields() throws {
        let original = TaskItem(
            title: "Round trip",
            isDone: true,
            isImportant: true,
            categoryID: UUID(),
            doneAt: Date(timeIntervalSince1970: 1_700_000_100),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            attachmentID: UUID()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TaskItem.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testAddTaskDefaultsAreFalseAndCreatedAtIsSet() {
        let task = TaskItem(title: "New task")

        XCTAssertFalse(task.isDone)
        XCTAssertFalse(task.isImportant)
        XCTAssertNil(task.categoryID)
        XCTAssertNil(task.doneAt)
    }
}

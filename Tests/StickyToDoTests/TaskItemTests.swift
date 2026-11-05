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
        XCTAssertEqual(task.attachmentIDs, [])
    }

    func testEncodeDecodeRoundTripPreservesAllFields() throws {
        let original = TaskItem(
            title: "Round trip",
            isDone: true,
            isImportant: true,
            categoryID: UUID(),
            doneAt: Date(timeIntervalSince1970: 1_700_000_100),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            attachmentIDs: [UUID(), UUID()]
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

    func testOlderSingleImageTasksLoadTheirImage() throws {
        let imageID = UUID()
        let json = #"{"id":"\#(UUID().uuidString)","title":"Old","attachmentID":"\#(imageID.uuidString)"}"#
        let task = try JSONDecoder().decode(TaskItem.self, from: Data(json.utf8))
        XCTAssertEqual(task.attachmentIDs, [imageID])
    }

    func testFirstImageIsAlsoSavedTheOldWayForOlderBuilds() throws {
        let ids = [UUID(), UUID()]
        let data = try JSONEncoder().encode(TaskItem(title: "New", attachmentIDs: ids))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["attachmentID"] as? String, ids[0].uuidString)
        XCTAssertEqual((object["attachmentIDs"] as? [String])?.count, 2)
    }
}

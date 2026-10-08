import XCTest
@testable import StickyToDo

final class CategoryUIStateTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var attachmentDirectory: URL!

    override func setUp() {
        super.setUp()
        suiteName = "StickyToDoTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        attachmentDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try? FileManager.default.removeItem(at: attachmentDirectory)
        attachmentDirectory = nil
        super.tearDown()
    }

    private func makeStore() -> TaskStore {
        TaskStore(userDefaults: defaults, attachmentStore: AttachmentStore(directory: attachmentDirectory))
    }

    func testNewTaskGetsNoCategoryOnAllTab() {
        let store = makeStore()
        store.createCategory(name: "Work")
        let categoryUI = CategoryUIState()

        XCTAssertNil(categoryUI.categoryIDForNewTask(in: store))
    }

    func testNewTaskLandsInSelectedCategory() {
        let store = makeStore()
        guard let work = store.createCategory(name: "Work") else {
            return XCTFail("Expected category to be created")
        }
        let categoryUI = CategoryUIState()
        categoryUI.selectedCategoryID = work.id

        XCTAssertEqual(categoryUI.categoryIDForNewTask(in: store), work.id)
    }

    func testNewTaskIgnoresSelectionOfDeletedCategory() {
        let store = makeStore()
        guard let work = store.createCategory(name: "Work") else {
            return XCTFail("Expected category to be created")
        }
        let categoryUI = CategoryUIState()
        categoryUI.selectedCategoryID = work.id
        store.deleteCategory(id: work.id)

        XCTAssertNil(categoryUI.categoryIDForNewTask(in: store))
    }
}

final class RevealNewTaskTests: XCTestCase {
    private let work = UUID()
    private let home = UUID()

    func testStaysOnAllTab() {
        let categoryUI = CategoryUIState()
        categoryUI.revealNewTask(inCategory: work)
        XCTAssertNil(categoryUI.selectedCategoryID)
    }

    func testStaysWhenTaskLandsInCurrentTab() {
        let categoryUI = CategoryUIState()
        categoryUI.selectedCategoryID = work
        categoryUI.revealNewTask(inCategory: work)
        XCTAssertEqual(categoryUI.selectedCategoryID, work)
    }

    func testSwitchesToOtherCategoryTab() {
        let categoryUI = CategoryUIState()
        categoryUI.selectedCategoryID = work
        categoryUI.revealNewTask(inCategory: home)
        XCTAssertEqual(categoryUI.selectedCategoryID, home)
    }

    func testSwitchesToAllForUncategorizedTask() {
        let categoryUI = CategoryUIState()
        categoryUI.selectedCategoryID = work
        categoryUI.revealNewTask(inCategory: nil)
        XCTAssertNil(categoryUI.selectedCategoryID)
    }
}

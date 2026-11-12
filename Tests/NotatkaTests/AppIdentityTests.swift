import XCTest
@testable import Notatka

final class AppIdentityTests: XCTestCase {
    func testRealAppGetsThePlainFolderName() {
        XCTAssertEqual(AppIdentity.notatka.folderName(forBundleID: "com.notatka.app"), "Notatka")
        XCTAssertEqual(AppIdentity.stickyToDo.folderName(forBundleID: "com.sticky.todo"), "StickyToDo")
    }

    func testOtherBuildsGetTheirOwnFolder() {
        XCTAssertEqual(AppIdentity.notatka.folderName(forBundleID: "com.notatka.app.test"), "Notatka (com.notatka.app.test)")
        XCTAssertEqual(AppIdentity.notatka.folderName(forBundleID: nil), "Notatka (unbundled)")
    }

    func testEachBuildMapsToItsStickyToDoCounterpart() {
        XCTAssertEqual(AppIdentity.notatka.counterpart(of: "com.notatka.app", in: .stickyToDo), "com.sticky.todo")
        XCTAssertEqual(AppIdentity.notatka.counterpart(of: "com.notatka.app.test", in: .stickyToDo), "com.sticky.todo.test")
    }

    func testUnrelatedBuildsHaveNoCounterpart() {
        XCTAssertNil(AppIdentity.notatka.counterpart(of: nil, in: .stickyToDo))
        XCTAssertNil(AppIdentity.notatka.counterpart(of: "com.apple.dt.xctest.tool", in: .stickyToDo))
        XCTAssertNil(AppIdentity.notatka.counterpart(of: "com.notatka.application", in: .stickyToDo))
    }
}

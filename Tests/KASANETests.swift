import XCTest
@testable import KASANE

final class KASANETests: XCTestCase {
    func testPlaceholderCopyIdentifiesTheApp() {
        XCTAssertEqual(ContentView.title, "KASANE")
        XCTAssertFalse(ContentView.subtitle.isEmpty)
    }
}

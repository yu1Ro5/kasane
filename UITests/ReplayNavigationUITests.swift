import XCTest

final class ReplayNavigationUITests: XCTestCase {
    @MainActor
    func testTapSwipeAndClosingActions() {
        let app = launchApp(additionalArguments: ["--fixture", "smart-start"])
        app.buttons["overview-replay-banner"].tap()

        let pages = app.descendants(matching: .any)["replay-pages"]
        let progress = app.descendants(matching: .any)["replay-page-progress"]
        XCTAssertTrue(pages.waitForExistence(timeout: 10))
        XCTAssertEqual(progress.value as? String, "5ページ中1ページ、Intro")
        XCTAssertFalse(app.buttons["replay-previous-button"].exists)
        XCTAssertFalse(app.buttons["replay-next-button"].exists)

        tapPage(pages, x: 0.25)
        XCTAssertEqual(progress.value as? String, "5ページ中1ページ、Intro")

        tapPage(pages, x: 0.75)
        XCTAssertEqual(progress.value as? String, "5ページ中2ページ、Activity")
        tapPage(pages, x: 0.25)
        XCTAssertEqual(progress.value as? String, "5ページ中1ページ、Intro")

        pages.swipeLeft()
        XCTAssertEqual(progress.value as? String, "5ページ中2ページ、Activity")
        pages.swipeUp()
        XCTAssertEqual(progress.value as? String, "5ページ中2ページ、Activity")
        pages.swipeRight()
        XCTAssertEqual(progress.value as? String, "5ページ中1ページ、Intro")

        for (position, title) in ["Activity", "Most Trained", "Growth & PR", "Closing"].enumerated() {
            tapPage(pages, x: 0.75)
            XCTAssertEqual(progress.value as? String, "5ページ中\(position + 2)ページ、\(title)")
        }
        tapPage(pages, x: 0.75, y: 0.95)
        XCTAssertEqual(progress.value as? String, "5ページ中5ページ、Closing")
        XCTAssertFalse(app.buttons["replay-previous-button"].exists)

        app.buttons["replay-restart-button"].tap()
        XCTAssertEqual(progress.value as? String, "5ページ中1ページ、Intro")
        for _ in 0..<4 { tapPage(pages, x: 0.75) }
        app.buttons["replay-closing-close-button"].tap()
        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHeaderActionsDoNotAdvancePage() {
        let app = launchApp(additionalArguments: ["--fixture", "smart-start"])
        app.buttons["overview-replay-banner"].tap()
        let progress = app.descendants(matching: .any)["replay-page-progress"]
        let yearSelector = app.buttons["replay-year-selector"]
        yearSelector.tap()
        XCTAssertEqual(progress.value as? String, "5ページ中1ページ、Intro")
        app.buttons.matching(NSPredicate(format: "label MATCHES %@", ".*2,?026年.*")).firstMatch.tap()
        XCTAssertEqual(progress.value as? String, "5ページ中1ページ、Intro")
        app.buttons["replay-close-button"].tap()
        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func tapPage(_ pages: XCUIElement, x: CGFloat, y: CGFloat = 0.55) {
        pages.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    }
}

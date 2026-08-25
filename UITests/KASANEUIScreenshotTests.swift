import XCTest

final class KASANEUIScreenshotTests: XCTestCase {
    @MainActor
    func testWorkoutWeightInputScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-three-exercises"]
        app.launch()

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))
        resumeButton.tap()

        let weightInput = app.textFields.matching(identifier: "draft-weight-input").firstMatch
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        weightInput.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "workout-weight-input"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutHistoryScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-history"]
        app.launch()

        let historyTab = app.tabBars.buttons["履歴"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10))
        historyTab.tap()
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン、ほか1種目"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "workout-history"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

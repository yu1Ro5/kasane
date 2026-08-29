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
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "workout-weight-input"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutCancelConfirmationScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-three-exercises"]
        app.launch()

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))
        resumeButton.tap()

        let moreButton = app.buttons["その他"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        moreButton.tap()

        let cancelWorkoutButton = app.buttons["ワークアウトを中止"]
        XCTAssertTrue(cancelWorkoutButton.waitForExistence(timeout: 5))
        cancelWorkoutButton.tap()

        XCTAssertTrue(app.staticTexts["ワークアウトを中止しますか？"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["中止する"].exists)
        XCTAssertTrue(app.buttons["続ける"].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "workout-cancel-confirmation"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["続ける"].tap()
        let finishButton = app.buttons["終了"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.tap()
        XCTAssertTrue(app.staticTexts["記録されたセットがありません"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["中止する"].exists)
        XCTAssertTrue(app.buttons["続ける"].exists)
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

    @MainActor
    func testWorkoutDetailScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-history"]
        app.launch()

        let historyTab = app.tabBars.buttons["履歴"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10))
        historyTab.tap()

        let historyRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "workout-history-row-")
        ).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        historyRow.tap()

        let detailView = app.descendants(matching: .any)["workout-detail-view"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["ワークアウト詳細"].exists)
        XCTAssertTrue(app.tabBars.buttons["履歴"].exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "workout-detail"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

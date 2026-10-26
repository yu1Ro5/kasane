import XCTest

final class KASANEUIScreenshotTests: XCTestCase {
    @MainActor
    func testPrimaryScreenshots() throws {
        let app = launchApp(additionalArguments: ["--fixture", "smart-start"])

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.descendants(matching: .any)["overview-workout-count"].waitForExistence(
                timeout: 10
            )
        )
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-total-volume"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-streak"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-calendar"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["overview-monthly-insight-card"].waitForExistence(
                timeout: 10
            )
        )
        addScreenshot(named: "overview-dashboard", of: app)

        let showAllWorkouts = app.buttons["overview-all-workouts"]
        XCTAssertTrue(scrollToHittable(showAllWorkouts, in: app))
        XCTAssertEqual(showAllWorkouts.label, "すべてのワークアウトを表示")
        showAllWorkouts.tap()

        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 10))
        let historyRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "workout-history-row-")
        )
        let historyRow = app.buttons["workout-history-row-\(overviewNewestSessionID)"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        XCTAssertEqual(historyRows.count, 5)
        XCTAssertTrue(historyRow.label.contains("ベンチプレス、ラットプルダウン"))
        addScreenshot(named: "workout-history", of: app)

        historyRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-detail-view"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.navigationBars["ワークアウト詳細"].exists)
        addScreenshot(named: "workout-detail", of: app)

        app.tabBars.buttons["ワークアウト"].tap()
        XCTAssertTrue(app.buttons["workout-start-button"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["最近のワークアウトから開始"].exists)
        let reusableSessionIDs = (1...3).map {
            "40000000-0000-4000-8000-00000000000\($0)"
        }
        for id in reusableSessionIDs {
            XCTAssertTrue(app.buttons["workout-reuse-\(id)"].exists)
        }
        XCTAssertFalse(app.buttons["workout-reuse-\(overviewOldestSessionID)"].exists)
        addScreenshot(named: "workout-smart-start-history", of: app)

        let reuse = app.buttons["workout-reuse-\(reusableSessionIDs[1])"]
        XCTAssertTrue(scrollToHittable(reuse, in: app))
        reuse.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.7)).tap()
        XCTAssertTrue(app.staticTexts["今回のワークアウト"].waitForExistence(timeout: 10))

        let currentExercise = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "current-exercise-")
        ).firstMatch
        XCTAssertTrue(currentExercise.waitForExistence(timeout: 10))
        currentExercise.tap()

        let weightInput = app.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "draft-weight-input-")
        ).firstMatch
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        addScreenshot(named: "workout-exercise-input", of: app)
    }

    @MainActor
    private func addScreenshot(named name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

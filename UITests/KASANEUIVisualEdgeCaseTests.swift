import XCTest

final class KASANEUIVisualEdgeCaseTests: XCTestCase {
    @MainActor
    func testAboutScreenshot() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        let aboutButton = app.buttons["KASANEについて"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 10))
        aboutButton.tap()

        XCTAssertTrue(app.navigationBars["KASANEについて"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["KASANE"].exists)
        XCTAssertTrue(app.staticTexts["サポート"].exists)
        XCTAssertTrue(app.staticTexts["プライバシーポリシー"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["about-version"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "about"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOverviewUnavailableInsightScreenshot() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "overview-recent-workouts",
            "--monthly-insight-unavailable",
        ])

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["overview-calendar"].exists)
        XCTAssertTrue(app.staticTexts["種目の記録"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["overview-monthly-insight-card"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-monthly-insight-unavailable"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOverviewDarkModeScreenshot() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "overview-recent-workouts",
            "-AppleInterfaceStyle", "Dark",
        ])

        XCTAssertTrue(
            app.descendants(matching: .any)["overview-workout-count"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)
        XCTAssertTrue(app.staticTexts["種目の記録"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["overview-calendar"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-dark-mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOverviewDynamicTypeScreenshot() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "overview-recent-workouts",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge",
        ])

        XCTAssertTrue(
            app.descendants(matching: .any)["overview-workout-count"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)
        XCTAssertTrue(app.staticTexts["種目の記録"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-dynamic-type"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutDynamicTypeScreenshot() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "workout-set-layout",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge",
        ])

        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["current-exercise-\(workoutSeatedRowExerciseID)"].tap()
        XCTAssertTrue(
            app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
                .waitForExistence(timeout: 10)
        )

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-dynamic-type"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import XCTest

final class KASANEUIVisualEdgeCaseTests: XCTestCase {
    @MainActor
    func testSettingsScreenshot() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        let settingsButton = app.buttons["設定"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["KASANEについて"].exists)
        XCTAssertFalse(app.staticTexts["アプリ情報"].exists)
        XCTAssertFalse(app.staticTexts["情報"].exists)
        XCTAssertTrue(scrollToHittable(app.staticTexts["© 2026 yu1Ro5"], in: app))
        XCTAssertTrue(app.staticTexts["サポート"].exists)
        XCTAssertTrue(app.staticTexts["プライバシーポリシー"].exists)
        let version = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "KASANE Version ")
        ).firstMatch
        XCTAssertTrue(version.exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "settings"
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
        XCTAssertTrue(app.staticTexts["最近の種目"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.descendants(matching: .any)["overview-calendar"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-dark-mode"
        attachment.lifetime = .keepAlways
        add(attachment)

        let historyLink = app.buttons["overview-all-workouts"]
        XCTAssertTrue(scrollToHittable(historyLink, in: app))
        let calendarAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        calendarAttachment.name = "overview-calendar-dark-mode"
        calendarAttachment.lifetime = .keepAlways
        add(calendarAttachment)
        XCTAssertTrue(scrollToHittable(app.staticTexts["最近の種目"], in: app))
    }

    @MainActor
    func testOverviewDynamicTypeScreenshot() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "overview-recent-workouts",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL",
        ])

        XCTAssertTrue(
            app.descendants(matching: .any)["overview-workout-count"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-dynamic-type"
        attachment.lifetime = .keepAlways
        add(attachment)

        let historyLink = app.buttons["overview-all-workouts"]
        XCTAssertTrue(scrollToHittable(historyLink, in: app))
        let calendarAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        calendarAttachment.name = "overview-calendar-dynamic-type"
        calendarAttachment.lifetime = .keepAlways
        add(calendarAttachment)
        XCTAssertTrue(scrollToHittable(app.staticTexts["最近の種目"], in: app))
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

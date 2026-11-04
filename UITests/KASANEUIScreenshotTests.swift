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
        // smart-startの最新Workoutは胸（ベンチプレス）と背中（ラットプルダウン）。
        // 履歴一覧は種目名でなく記録時の部位を表示する。
        XCTAssertTrue(historyRow.label.contains("胸・背中"))
        XCTAssertTrue(historyRow.label.contains("2種目"))
        XCTAssertTrue(historyRow.label.contains("60分"))
        XCTAssertFalse(historyRow.label.contains("ベンチプレス、ラットプルダウン"))
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

        let searchButton = app.buttons["workout-exercise-search-button"]
        XCTAssertTrue(scrollToHittable(searchButton, in: app))
        XCTAssertFalse(app.textFields["workout-exercise-search-field"].exists)
        searchButton.tap()
        let searchField = app.textFields["workout-exercise-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        searchField.typeText("存在しない種目212")
        XCTAssertFalse(app.staticTexts["今回のワークアウト"].exists)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "available-exercise-")).count, 0)
        app.buttons["workout-exercise-search-clear"].tap()
        XCTAssertTrue(app.staticTexts["今回のワークアウト"].exists)
        app.buttons["workout-exercise-search-cancel"].tap()
        XCTAssertFalse(searchField.exists)

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

    /// Opt in only from the manual workflow (TEST_RUNNER_ is forwarded by xcodebuild).
    @MainActor
    func testAppStoreScreenshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOTS"] == "1",
            "App Store screenshots are enabled only by the dedicated manual workflow."
        )
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let appearance = [
            "-AppleInterfaceStyle", "light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        // launchApp supplies the shared Japanese/UI-testing arguments. Relaunch with a fixed
        // time zone so Calendar.current and date labels do not depend on the runner's locale.
        let launchFixture: ([String]) -> XCUIApplication = { arguments in
            let app = self.launchApp(additionalArguments: arguments + appearance)
            app.terminate()
            app.launchEnvironment["TZ"] = "Asia/Tokyo"
            app.launch()
            self.waitForAppToBeStable(app)
            return app
        }
        var app = launchFixture(["--fixture", "smart-start"])
        defer { app.terminate() }

        let count = app.descendants(matching: .any)["overview-workout-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.value as? String, "3回")
        XCTAssertEqual(
            app.descendants(matching: .any)["overview-month-selector"].value as? String,
            "2026年9月"
        )
        let banner = app.buttons["overview-replay-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertTrue(banner.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["overview-total-volume"].exists)
        addScreenshot(named: "app-store-01-overview", of: app)

        app.tabBars.buttons["ワークアウト"].tap()
        let reuse = app.buttons["workout-reuse-\(overviewNewestSessionID)"]
        XCTAssertTrue(scrollToHittable(reuse, in: app))
        reuse.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.7)).tap()
        let bench = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "current-exercise-", "ベンチプレス")
        ).firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 10))
        let exerciseID = String(bench.identifier.dropFirst("current-exercise-".count))
        bench.tap()
        XCTAssertTrue(app.navigationBars["ベンチプレス"].waitForExistence(timeout: 10))
        let weight = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "draft-weight-input-"))
            .firstMatch
        let reps = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "draft-reps-input-"))
            .firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        XCTAssertTrue(reps.exists)
        let previous = app.descendants(matching: .any)["previous-workout-record-\(exerciseID)"]
        XCTAssertTrue(previous.waitForExistence(timeout: 10))
        XCTAssertTrue(previous.isHittable)
        XCTAssertTrue(weight.isHittable && reps.isHittable)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        addScreenshot(named: "app-store-02-workout-input", of: app)

        app.terminate()
        app = launchFixture(["--fixture", "smart-start"])
        let replay = app.buttons["overview-replay-banner"]
        XCTAssertTrue(replay.waitForExistence(timeout: 10))
        replay.tap()
        XCTAssertTrue(app.descendants(matching: .any)["replay-intro-page"].waitForExistence(timeout: 10))
        let replayYear = app.descendants(matching: .any)["replay-year-selector"]
        XCTAssertTrue(replayYear.waitForExistence(timeout: 10))
        // Validate the selected year through its semantic value, independent of Text's
        // locale-specific number grouping (for example, "2,026").
        let replayYearValue = try XCTUnwrap(replayYear.value as? String)
        XCTAssertEqual(String(replayYearValue.filter(\.isNumber)), "2026")
        // The accessibility snapshot includes both the combined metric (.other) and
        // its child label (.staticText). Select the metric that owns the count value.
        let replayCount = app.descendants(matching: .any)["replay-intro-page"]
            .descendants(matching: .other)
            .matching(NSPredicate(format: "label == %@", "完了したワークアウト"))
            .element
        XCTAssertTrue(replayCount.waitForExistence(timeout: 10))
        XCTAssertEqual(replayCount.value as? String, "5回")
        addScreenshot(named: "app-store-03-replay", of: app)

        app.terminate()
        app = launchFixture(["--fixture", "workout-set-layout", "--workout-ai-fixture"])
        app.tabBars.buttons["ワークアウト"].tap()
        let quickInput = app.buttons["workout-ai-quick-input-button"]
        XCTAssertTrue(quickInput.waitForExistence(timeout: 10))
        quickInput.tap()
        let input = app.descendants(matching: .any)["workout-ai-input-text"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("チェストプレス30kgを10回3セット。ラットプル18kgを12回3セット。")
        app.buttons["workout-ai-analyze-button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["workout-ai-review"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["チェストプレス"].exists)
        let lat = app.staticTexts["ラットプルダウン"]
        XCTAssertTrue(lat.exists)
        XCTAssertEqual(app.textFields.matching(NSPredicate(format: "label CONTAINS 'の回数'")).count, 6)
        XCTAssertTrue(app.buttons["workout-ai-apply-button"].isEnabled)
        // Scroll the review itself in small increments; an application-wide swipe can
        // miss the scroll view or pass the position where both headings are visible.
        let reviewScroll = app.scrollViews.firstMatch
        XCTAssertTrue(reviewScroll.waitForExistence(timeout: 10))
        let headingIsVisible: (XCUIElement) -> Bool = { element in
            let viewport = reviewScroll.frame.intersection(app.windows.firstMatch.frame)
            let frame = element.frame
            return !viewport.isEmpty && frame.isFiniteNonZero && viewport.contains(frame)
        }
        for _ in 0..<12 {
            if headingIsVisible(lat) { break }
            let needsEarlierContent = lat.frame.minY < reviewScroll.frame.minY
            let start = reviewScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.65))
            let end = reviewScroll.coordinate(
                withNormalizedOffset: CGVector(dx: 0.95, dy: needsEarlierContent ? 0.77 : 0.53)
            )
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        // Text labels are validated by their visible frames, rather than tap eligibility.
        XCTAssertTrue(headingIsVisible(lat), "The second exercise heading must be fully visible")
        XCTAssertTrue(
            headingIsVisible(app.staticTexts["チェストプレス"]),
            "Both exercise headings must be visible in the same screenshot"
        )
        addScreenshot(named: "app-store-04-ai-quick-input", of: app)

        app.terminate()
        app = launchFixture(["--fixture", "personal-record", "--workout-insight-fixture"])
        app.tabBars.buttons["ワークアウト"].tap()
        XCTAssertTrue(app.buttons["終了"].waitForExistence(timeout: 10))
        app.buttons["終了"].tap()
        XCTAssertTrue(app.buttons["終了して保存"].waitForExistence(timeout: 5))
        app.buttons["終了して保存"].tap()
        XCTAssertTrue(app.staticTexts["NEW RECORD"].waitForExistence(timeout: 10))
        for label in ["レッグプレス", "Previous", "63.00 kg", "New Record", "前回より +9.00 kg"] {
            XCTAssertTrue(app.staticTexts[label].isHittable)
        }
        XCTAssertTrue(app.staticTexts["72.00 kg"].firstMatch.isHittable)
        XCTAssertTrue(app.buttons["personal-record-continue-button"].exists)
        addScreenshot(named: "app-store-05-personal-record", of: app)
    }

    @MainActor
    private func addScreenshot(named name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

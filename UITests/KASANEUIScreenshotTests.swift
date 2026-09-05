import XCTest

final class KASANEUIScreenshotTests: XCTestCase {
    private let historySessionID = "50000000-0000-4000-8000-000000000001"
    private let overviewNewestSessionID = "40000000-0000-4000-8000-000000000001"
    private let workoutSeatedRowEntryID = "21000000-0000-4000-8000-000000000001"
    private let workoutNoPreviousEntryID = "21000000-0000-4000-8000-000000000002"

    // UIが安定し、最前面ウィンドウのフレームが有限かつゼロでないことを確認してから進む
    @MainActor private func waitForAppToBeStable(_ app: XCUIApplication, timeout: TimeInterval = 5.0) {
        // ウィンドウが存在するまで待機
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: timeout))

        // フレームが安定するまでポーリング
        let deadline = Date().addingTimeInterval(timeout)
        var lastFrame = CGRect.null
        repeat {
            let frame = window.frame
            if frame.isFiniteNonZero { return }
            // フレームが変化している最中の可能性があるので、少し待つ
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            lastFrame = frame
        } while Date() < deadline

        // タイムアウト時も一応検証して失敗させる
        XCTAssertTrue(window.frame.isFiniteNonZero, "ウィンドウのフレームが安定しませんでした: \(lastFrame)")
    }

    // スクリーンショットを撮る前にUIを安定させる
    @MainActor private func takeStableScreenshot(_ app: XCUIApplication) -> XCUIScreenshot {
        waitForAppToBeStable(app)
        return XCUIScreen.main.screenshot()
    }

    @MainActor
    func testOverviewEmptyScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        waitForAppToBeStable(app)

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["概要"].exists)
        XCTAssertTrue(app.tabBars.buttons["ワークアウト"].exists)
        XCTAssertTrue(app.staticTexts["ワークアウトがありません"].exists)
        XCTAssertTrue(app.staticTexts["完了したワークアウトがここに表示されます。"].exists)
        XCTAssertFalse(app.buttons["履歴"].exists)
        XCTAssertFalse(app.tabBars.buttons["履歴"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-empty"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOverviewRecentWorkoutsScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "overview-recent-workouts"]
        app.launch()
        waitForAppToBeStable(app)

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["最近のワークアウト"].exists)
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン"].exists)
        XCTAssertTrue(app.staticTexts["スクワット"].exists)
        XCTAssertTrue(app.staticTexts["ショルダープレス"].exists)
        XCTAssertFalse(app.staticTexts["デッドリフト"].exists)
        XCTAssertFalse(app.staticTexts["アクティブテスト種目"].exists)
        XCTAssertTrue(app.buttons["すべて表示"].exists)
        XCTAssertTrue(app.tabBars.buttons["概要"].exists)
        XCTAssertTrue(app.tabBars.buttons["ワークアウト"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-recent-workouts"
        attachment.lifetime = .keepAlways
        add(attachment)

        let recentRow = app.buttons["overview-recent-workout-row-\(overviewNewestSessionID)"]
        XCTAssertTrue(recentRow.waitForExistence(timeout: 10))
        recentRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-detail-view"].waitForExistence(timeout: 10)
        )

        app.navigationBars["ワークアウト詳細"].buttons["概要"].tap()
        XCTAssertTrue(app.buttons["すべて表示"].waitForExistence(timeout: 10))
        app.buttons["すべて表示"].tap()
        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["デッドリフト"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["アクティブテスト種目"].exists)
    }

    @MainActor
    func testOverviewSearchResultsScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "overview-recent-workouts"]
        app.launch()
        waitForAppToBeStable(app)

        let searchButton = app.buttons["検索"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 10))
        searchButton.tap()
        XCTAssertTrue(app.navigationBars["検索"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-search-unsearched"].waitForExistence(
                timeout: 10
            )
        )
        XCTAssertFalse(
            app.buttons["workout-search-result-row-\(overviewNewestSessionID)"].exists
        )

        let searchField = app.searchFields["種目名を検索"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("プレス")

        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["ショルダープレス"].exists)
        XCTAssertFalse(app.staticTexts["スクワット"].exists)
        XCTAssertFalse(app.staticTexts["デッドリフト"].exists)
        XCTAssertFalse(app.staticTexts["アクティブテスト種目"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-search-results"
        attachment.lifetime = .keepAlways
        add(attachment)

        let resultRow = app.buttons["workout-search-result-row-\(overviewNewestSessionID)"]
        XCTAssertTrue(resultRow.waitForExistence(timeout: 10))
        resultRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-detail-view"].waitForExistence(timeout: 10)
        )
    }

    @MainActor
    func testOverviewSearchEmptyScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "overview-recent-workouts"]
        app.launch()
        waitForAppToBeStable(app)

        let searchButton = app.buttons["検索"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 10))
        searchButton.tap()
        XCTAssertTrue(app.navigationBars["検索"].waitForExistence(timeout: 10))

        let searchField = app.searchFields["種目名を検索"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("存在しない種目")

        XCTAssertTrue(
            app.descendants(matching: .any)["workout-search-empty"].waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.staticTexts["ベンチプレス、ラットプルダウン"].exists)
        XCTAssertFalse(app.staticTexts["ショルダープレス"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-search-empty"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutRootEmptyScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()

        let startButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        XCTAssertEqual(startButton.label, "ワークアウトを開始")

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-root-empty"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))

        let activeRootAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        activeRootAttachment.name = "workout-root-active"
        activeRootAttachment.lifetime = .keepAlways
        add(activeRootAttachment)

        resumeButton.tap()

        let weightInput = app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))

        let sessionAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        sessionAttachment.name = "workout-session-active"
        sessionAttachment.lifetime = .keepAlways
        add(sessionAttachment)

        weightInput.tap()
        weightInput.typeText("47.5")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 0)

        app.buttons["次へ"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 0)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)
        let repsInput = app.textFields["draft-reps-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(repsInput.waitForExistence(timeout: 5))
        repsInput.typeText("8")

        let weightInputAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        weightInputAttachment.name = "workout-weight-input"
        weightInputAttachment.lifetime = .keepAlways
        add(weightInputAttachment)
        app.buttons["完了"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        let addExerciseButton = app.buttons["種目を追加"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10))
        addExerciseButton.tap()
        let searchField = app.searchFields["種目名を検索"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        let exercisePickerAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        exercisePickerAttachment.name = "exercise-picker"
        exercisePickerAttachment.lifetime = .keepAlways
        add(exercisePickerAttachment)

        app.buttons["キャンセル"].tap()
        XCTAssertTrue(searchField.waitForNonExistence(timeout: 5))

        let moreButton = app.buttons["その他"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        moreButton.tap()

        let cancelWorkoutButton = app.buttons["ワークアウトを中止"]
        XCTAssertTrue(cancelWorkoutButton.waitForExistence(timeout: 5))
        cancelWorkoutButton.tap()

        XCTAssertTrue(
            app.staticTexts["このワークアウトの記録は削除され、元に戻せません。"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["中止する"].exists)

        let cancelConfirmationAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        cancelConfirmationAttachment.name = "workout-cancel-confirmation"
        cancelConfirmationAttachment.lifetime = .keepAlways
        add(cancelConfirmationAttachment)
    }

    @MainActor
    func testWorkoutValidationScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["workout-resume-button"].tap()

        let weightInput = app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        weightInput.tap()
        weightInput.typeText("12.345")
        app.buttons["次へ"].tap()
        app.buttons["完了"].tap()

        XCTAssertTrue(
            app.staticTexts["draft-validation-message"].waitForExistence(timeout: 5)
        )
        let addSetButton = app.buttons["add-set-button-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(addSetButton.exists)
        XCTAssertFalse(addSetButton.isEnabled)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-validation-error"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutPreviousRecordScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["workout-resume-button"].tap()

        let previousRecord = app.descendants(matching: .any)[
            "previous-workout-record-\(workoutSeatedRowEntryID)"
        ]
        XCTAssertTrue(previousRecord.waitForExistence(timeout: 10))
        for order in 0..<3 {
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "previous-set-row-\(workoutSeatedRowEntryID)-\(order)"
                ].exists
            )
        }

        let availableAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        availableAttachment.name = "workout-previous-record-available"
        availableAttachment.lifetime = .keepAlways
        add(availableAttachment)

        let noPreviousWeightInput = app.textFields[
            "draft-weight-input-\(workoutNoPreviousEntryID)"
        ]
        XCTAssertTrue(noPreviousWeightInput.waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "previous-workout-record-\(workoutNoPreviousEntryID)"
            ].exists
        )

        let unavailableAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        unavailableAttachment.name = "workout-previous-record-unavailable"
        unavailableAttachment.lifetime = .keepAlways
        add(unavailableAttachment)
    }

    @MainActor
    func testWorkoutDynamicTypeScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--fixture", "workout-set-layout",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge",
        ]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["workout-resume-button"].tap()
        XCTAssertTrue(
            app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
                .waitForExistence(timeout: 10)
        )

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-dynamic-type"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutCompletedScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))
        resumeButton.tap()

        let finishButton = app.buttons["終了"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10))
        finishButton.tap()
        let saveButton = app.buttons["終了して保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["ワークアウトを記録しました"].waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-completed"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutHistoryScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-history"]
        app.launch()
        waitForAppToBeStable(app)

        let historyLink = app.buttons["すべて表示"]
        XCTAssertTrue(historyLink.waitForExistence(timeout: 10))
        historyLink.tap()
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン、ほか1種目"].waitForExistence(timeout: 10))

        let historyAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        historyAttachment.name = "workout-history"
        historyAttachment.lifetime = .keepAlways
        add(historyAttachment)

        let historyRow = app.buttons["workout-history-row-\(historySessionID)"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        historyRow.tap()

        let detailView = app.descendants(matching: .any)["workout-detail-view"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["ワークアウト詳細"].exists)
        XCTAssertTrue(app.navigationBars["ワークアウト詳細"].buttons["履歴"].exists)
        XCTAssertTrue(app.tabBars.buttons["概要"].exists)
        XCTAssertTrue(app.tabBars.buttons["ワークアウト"].exists)

        let detailAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        detailAttachment.name = "workout-detail"
        detailAttachment.lifetime = .keepAlways
        add(detailAttachment)

        let editButton = app.buttons["編集"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10))
        editButton.tap()

        let editView = app.descendants(matching: .any)["workout-detail-edit-mode"]
        XCTAssertTrue(editView.waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["ワークアウト詳細"].exists)
        let existingWeightInput = app.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history-edit-weight-input-")
        ).firstMatch
        XCTAssertTrue(existingWeightInput.exists)
        XCTAssertTrue(app.buttons["保存"].exists)
        XCTAssertTrue(app.buttons["キャンセル"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-detail-edit-mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testActiveWorkoutPersistsAcrossTabSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()
        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))
        resumeButton.tap()

        let weightInput = app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))

        app.tabBars.buttons["概要"].tap()
        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        app.tabBars.buttons["ワークアウト"].tap()

        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["終了"].exists)
    }

    @MainActor
    func testWorkoutDetailEditingFlow() throws {
        let historyEditExerciseID = "30000000-0000-4000-8000-000000000001"
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-history"]
        app.launch()
        waitForAppToBeStable(app)

        let historyLink = app.buttons["すべて表示"]
        XCTAssertTrue(historyLink.waitForExistence(timeout: 10))
        historyLink.tap()
        let historyRow = app.buttons["workout-history-row-\(historySessionID)"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        historyRow.tap()

        let editButton = app.buttons["編集"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10))
        editButton.tap()

        let editView = app.descendants(matching: .any)["workout-detail-edit-mode"]
        XCTAssertTrue(editView.waitForExistence(timeout: 10))
        app.buttons["種目を追加"].tap()
        let searchField = app.searchFields["種目名を検索"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("履歴編集テスト種目")
        let addedExerciseButton = app.buttons["履歴編集テスト種目"]
        XCTAssertTrue(addedExerciseButton.waitForExistence(timeout: 5))
        addedExerciseButton.tap()

        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.staticTexts["保存していない変更は失われます。"].waitForExistence(timeout: 5))
        app.buttons["破棄する"].tap()

        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        app.buttons["種目を追加"].tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("履歴編集テスト種目")
        XCTAssertTrue(addedExerciseButton.waitForExistence(timeout: 5))
        addedExerciseButton.tap()

        editView.swipeUp()
        editView.swipeUp()
        editView.swipeUp()
        let addSetButton = app.buttons["history-edit-add-set-\(historyEditExerciseID)"]
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 5))
        addSetButton.tap()
        let addedWeightInput = app.textFields.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "history-edit-weight-input-\(historyEditExerciseID)-"
            )
        ).firstMatch
        let addedRepsInput = app.textFields.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "history-edit-reps-input-\(historyEditExerciseID)-"
            )
        ).firstMatch
        XCTAssertTrue(addedWeightInput.waitForExistence(timeout: 5))
        addedWeightInput.tap()
        addedWeightInput.typeText("100")
        addedRepsInput.tap()
        addedRepsInput.typeText("5")
        app.buttons["完了"].tap()
        app.buttons["保存"].tap()

        let detailView = app.descendants(matching: .any)["workout-detail-view"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["編集"].exists)
        detailView.swipeUp()
        detailView.swipeUp()
        detailView.swipeUp()
        XCTAssertTrue(app.staticTexts["履歴編集テスト種目"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["100.00 kg"].exists)

        app.navigationBars["ワークアウト詳細"].buttons["履歴"].tap()
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン、ほか2種目"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["52分・4種目"].exists)
    }
}

extension CGRect {
    /// フレームの幅・高さが有限かつ正であるか
    var isFiniteNonZero: Bool {
        guard width.isFinite, height.isFinite else { return false }
        return width > 0 && height > 0
    }
}

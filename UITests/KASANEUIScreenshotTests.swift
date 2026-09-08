import XCTest

final class KASANEUIScreenshotTests: XCTestCase {
    private let historySessionID = "50000000-0000-4000-8000-000000000001"
    private let overviewNewestSessionID = "40000000-0000-4000-8000-000000000001"
    private let overviewOldestSessionID = "40000000-0000-4000-8000-000000000004"
    private let workoutSeatedRowExerciseID = "00000000-0000-4000-8000-000000000006"
    private let workoutNoPreviousExerciseID = "20000000-0000-4000-8000-000000000002"
    private let workoutShoulderPressExerciseID = "00000000-0000-4000-8000-000000000009"
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
    func testEmptyScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        waitForAppToBeStable(app)

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["概要"].exists)
        XCTAssertTrue(app.tabBars.buttons["ワークアウト"].exists)
        XCTAssertTrue(app.staticTexts["今月のトレーニング"].exists)
        XCTAssertTrue(app.staticTexts["最初の記録から、少しずつ。"].exists)
        XCTAssertTrue(app.staticTexts["ワークアウトがありません"].exists)
        XCTAssertTrue(app.staticTexts["完了したワークアウトがここに表示されます。"].exists)
        XCTAssertFalse(app.buttons["履歴"].exists)
        XCTAssertFalse(app.tabBars.buttons["履歴"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-empty"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.tabBars.buttons["ワークアウト"].tap()

        let startButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        XCTAssertEqual(startButton.label, "ワークアウトを開始")

        let workoutAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        workoutAttachment.name = "workout-root-empty"
        workoutAttachment.lifetime = .keepAlways
        add(workoutAttachment)
    }

    @MainActor
    func testOverviewScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "overview-recent-workouts"]
        app.launch()
        waitForAppToBeStable(app)

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["overview-workout-count"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)
        XCTAssertTrue(app.staticTexts["overview-active-days"].exists)
        XCTAssertTrue(app.staticTexts["今月よく行う種目"].exists)
        XCTAssertTrue(app.staticTexts["最近のワークアウト"].exists)
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン"].exists)
        XCTAssertTrue(app.staticTexts["スクワット"].exists)
        XCTAssertTrue(app.staticTexts["ショルダープレス"].exists)
        XCTAssertFalse(app.staticTexts["デッドリフト"].exists)
        XCTAssertFalse(app.staticTexts["アクティブテスト種目"].exists)
        XCTAssertTrue(app.tabBars.buttons["概要"].exists)
        XCTAssertTrue(app.tabBars.buttons["ワークアウト"].exists)

        let recentWorkoutsAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        recentWorkoutsAttachment.name = "overview-recent-workouts"
        recentWorkoutsAttachment.lifetime = .keepAlways
        add(recentWorkoutsAttachment)

        let recentRow = app.buttons["overview-recent-workout-row-\(overviewNewestSessionID)"]
        XCTAssertTrue(recentRow.waitForExistence(timeout: 10))
        recentRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-detail-view"].waitForExistence(timeout: 10)
        )

        app.navigationBars["ワークアウト詳細"].buttons["概要"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["すべて表示"].waitForExistence(timeout: 10))
        app.buttons["すべて表示"].tap()
        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["デッドリフト"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["アクティブテスト種目"].exists)

        let oldestHistoryRow = app.buttons["workout-history-row-\(overviewOldestSessionID)"]
        XCTAssertTrue(oldestHistoryRow.waitForExistence(timeout: 10))
        oldestHistoryRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-detail-view"].waitForExistence(timeout: 10)
        )
        let historyBackButton = app.navigationBars["ワークアウト詳細"].buttons["履歴"]
        XCTAssertTrue(historyBackButton.waitForExistence(timeout: 10))
        historyBackButton.tap()
        let overviewBackButton = app.navigationBars["履歴"].buttons["概要"]
        XCTAssertTrue(overviewBackButton.waitForExistence(timeout: 10))
        overviewBackButton.tap()

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))

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

        let searchResultsAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        searchResultsAttachment.name = "overview-search-results"
        searchResultsAttachment.lifetime = .keepAlways
        add(searchResultsAttachment)

        searchField.tap()
        // 現在入力されている文字を取得
        guard let text = searchField.value as? String else { return }
        // 取得した文字数分削除ボタンを押す
        var delete = String(
            repeating: XCUIKeyboardKey.delete.rawValue,
            count: text.count
        )
        // 削除
        searchField.typeText(delete)
        searchField.typeText("デッドリフト")

        let oldestSearchRow = app.buttons[
            "workout-search-result-row-\(overviewOldestSessionID)"
        ]
        XCTAssertTrue(oldestSearchRow.waitForExistence(timeout: 10))
        oldestSearchRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-detail-view"].waitForExistence(timeout: 10)
        )
        let searchBackButton = app.navigationBars["ワークアウト詳細"].buttons["検索"]
        XCTAssertTrue(searchBackButton.waitForExistence(timeout: 10))
        searchBackButton.tap()

        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        // 現在入力されている文字を取得
        guard let text = searchField.value as? String else { return }
        // 取得した文字数分削除ボタンを押す
        delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
        // 削除
        searchField.typeText(delete)
        searchField.typeText("存在しない種目")

        XCTAssertTrue(
            app.descendants(matching: .any)["workout-search-empty"].waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.staticTexts["ベンチプレス、ラットプルダウン"].exists)
        XCTAssertFalse(app.staticTexts["ショルダープレス"].exists)

        let searchEmptyAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        searchEmptyAttachment.name = "overview-search-empty"
        searchEmptyAttachment.lifetime = .keepAlways
        add(searchEmptyAttachment)
    }

    @MainActor
    func testOverviewPreviousMonthScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "overview-previous-month"]
        app.launch()
        waitForAppToBeStable(app)

        XCTAssertTrue(app.staticTexts["今月の記録はまだありません"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["最近のワークアウト"].exists)
        XCTAssertTrue(app.staticTexts["デッドリフト"].exists)
        XCTAssertFalse(app.staticTexts["今月よく行う種目"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-previous-month"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOverviewDarkModeScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--fixture", "overview-recent-workouts",
            "-AppleInterfaceStyle", "Dark",
        ]
        app.launch()
        waitForAppToBeStable(app)

        XCTAssertTrue(
            app.descendants(matching: .any)["overview-workout-count"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)
        XCTAssertTrue(app.staticTexts["今月よく行う種目"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-dark-mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOverviewDynamicTypeScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--fixture", "overview-recent-workouts",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge",
        ]
        app.launch()
        waitForAppToBeStable(app)

        XCTAssertTrue(
            app.descendants(matching: .any)["overview-workout-count"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-dynamic-type"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutInteractionScreenshots() throws {
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

        XCTAssertTrue(app.staticTexts["今回のワークアウト"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["すべての種目"].exists)
        XCTAssertTrue(app.searchFields["種目名を検索"].exists)

        let sessionAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        sessionAttachment.name = "workout-session-active"
        sessionAttachment.lifetime = .keepAlways
        add(sessionAttachment)

        let currentExercise = app.buttons["current-exercise-\(workoutSeatedRowExerciseID)"]
        XCTAssertTrue(currentExercise.waitForExistence(timeout: 10))
        currentExercise.tap()

        let weightInput = app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))

        let inputAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        inputAttachment.name = "workout-exercise-input"
        inputAttachment.lifetime = .keepAlways
        add(inputAttachment)

        weightInput.tap()
        weightInput.typeText("47.5")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 0)

        app.buttons["次へ"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 0)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)
        let keyboardAddSetButton = app.buttons["keyboard-add-set-button"]
        XCTAssertTrue(keyboardAddSetButton.exists)
        XCTAssertFalse(keyboardAddSetButton.isEnabled)
        let repsInput = app.textFields["draft-reps-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(repsInput.waitForExistence(timeout: 5))
        repsInput.typeText("8")
        XCTAssertTrue(keyboardAddSetButton.isEnabled)

        let weightInputAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        weightInputAttachment.name = "workout-weight-input"
        weightInputAttachment.lifetime = .keepAlways
        add(weightInputAttachment)
        keyboardAddSetButton.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(weightInput.waitForExistence(timeout: 5))
        XCTAssertEqual(weightInput.value as? String, "0")
        XCTAssertEqual(repsInput.value as? String, "0")
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "keyboard-add-set-button").count, 0)

        weightInput.typeText("50")
        XCTAssertEqual(weightInput.value as? String, "50")
        app.buttons["次へ"].tap()
        repsInput.typeText("6")
        app.buttons["完了"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        app.navigationBars.buttons["ワークアウト"].tap()

        let moreButton = app.buttons["その他"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        moreButton.tap()

        let cancelWorkoutButton = app.buttons["ワークアウトを中止"]
        XCTAssertTrue(cancelWorkoutButton.waitForExistence(timeout: 5))
        cancelWorkoutButton.tap()

        let cancelMessage = app.staticTexts["このワークアウトの記録は削除され、元に戻せません。"]
        XCTAssertTrue(cancelMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["中止する"].exists)

        let cancelConfirmationAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        cancelConfirmationAttachment.name = "workout-cancel-confirmation"
        cancelConfirmationAttachment.lifetime = .keepAlways
        add(cancelConfirmationAttachment)

        let finishButton = app.buttons["終了"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10))
        finishButton.tap()
        XCTAssertTrue(cancelMessage.waitForNonExistence(timeout: 5))

        let searchField = app.searchFields["種目名を検索"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("ショルダー")
        XCTAssertTrue(app.staticTexts["ショルダープレス"].waitForExistence(timeout: 5))

        let searchAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        searchAttachment.name = "workout-exercise-search"
        searchAttachment.lifetime = .keepAlways
        add(searchAttachment)

        let availableExercise = app.buttons[
            "available-exercise-\(workoutShoulderPressExerciseID)"
        ]
        XCTAssertTrue(availableExercise.exists)
        availableExercise.tap()
        let pendingWeightInput = app.textFields[
            "draft-weight-input-\(workoutShoulderPressExerciseID)"
        ]
        XCTAssertTrue(pendingWeightInput.waitForExistence(timeout: 5))
        pendingWeightInput.tap()
        pendingWeightInput.typeText("14")
        app.navigationBars.buttons["ワークアウト"].tap()
        XCTAssertTrue(
            app.buttons["available-exercise-\(workoutShoulderPressExerciseID)"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["current-exercise-\(workoutShoulderPressExerciseID)"].exists)

        app.buttons["available-exercise-\(workoutShoulderPressExerciseID)"].tap()
        XCTAssertTrue(pendingWeightInput.waitForExistence(timeout: 5))
        XCTAssertEqual(pendingWeightInput.value as? String, "14")
        app.navigationBars.buttons["ワークアウト"].tap()
    }

    @MainActor
    func testWorkoutValidationAndCompletionScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["workout-resume-button"].tap()
        app.buttons["current-exercise-\(workoutSeatedRowExerciseID)"].tap()

        let weightInput = app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        weightInput.tap()
        weightInput.typeText("12.34")
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

        let repsInput = app.textFields["draft-reps-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(repsInput.waitForExistence(timeout: 5))

        // 追加: まずタップしてフォーカス＆キーボードを出す
        repsInput.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        // その後に typeText
        repsInput.typeText("1")
        app.buttons["完了"].tap()
        XCTAssertTrue(
            app.staticTexts["draft-validation-message"].waitForNonExistence(timeout: 5)
        )

        app.navigationBars.buttons["ワークアウト"].tap()
        let finishButton = app.buttons["終了"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10))
        finishButton.tap()
        let saveButton = app.buttons["終了して保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["ワークアウトを記録しました"].waitForExistence(timeout: 10))
        let completedAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        completedAttachment.name = "workout-completed"
        completedAttachment.lifetime = .keepAlways
        add(completedAttachment)
    }

    @MainActor
    func testWorkoutPreviousRecordScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["workout-resume-button"].tap()
        app.buttons["current-exercise-\(workoutSeatedRowExerciseID)"].tap()

        app.swipeUp()

        let previousRecord = app.descendants(matching: .any)[
            "previous-workout-record-\(workoutSeatedRowExerciseID)"
        ]
        XCTAssertTrue(previousRecord.waitForExistence(timeout: 10))
        for order in 0..<3 {
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "previous-set-row-\(workoutSeatedRowExerciseID)-\(order)"
                ].exists
            )
        }

        let availableAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        availableAttachment.name = "workout-previous-record-available"
        availableAttachment.lifetime = .keepAlways
        add(availableAttachment)

        app.navigationBars.buttons["ワークアウト"].tap()
        app.buttons["current-exercise-\(workoutNoPreviousExerciseID)"].tap()
        let noPreviousWeightInput = app.textFields["draft-weight-input-\(workoutNoPreviousEntryID)"]
        XCTAssertTrue(noPreviousWeightInput.waitForExistence(timeout: 10))
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "previous-workout-record-\(workoutNoPreviousExerciseID)"
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
}

extension CGRect {
    /// フレームの幅・高さが有限かつ正であるか
    var isFiniteNonZero: Bool {
        guard width.isFinite, height.isFinite else { return false }
        return width > 0 && height > 0
    }
}

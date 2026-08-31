import XCTest

final class KASANEUIScreenshotTests: XCTestCase {
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
    func testWorkoutRootEmptyScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        waitForAppToBeStable(app)

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

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))

        let activeRootAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        activeRootAttachment.name = "workout-root-active"
        activeRootAttachment.lifetime = .keepAlways
        add(activeRootAttachment)

        resumeButton.tap()

        let weightInput = app.textFields.matching(identifier: "draft-weight-input").firstMatch
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        weightInput.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)

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
    func testWorkoutCompletedScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-set-layout"]
        app.launch()
        waitForAppToBeStable(app)

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

        let historyTab = app.tabBars.buttons["履歴"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10))
        historyTab.tap()
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン、ほか1種目"].waitForExistence(timeout: 10))

        let historyAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        historyAttachment.name = "workout-history"
        historyAttachment.lifetime = .keepAlways
        add(historyAttachment)

        let historyRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "workout-history-row-")
        ).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        historyRow.tap()

        let detailView = app.descendants(matching: .any)["workout-detail-view"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["ワークアウト詳細"].exists)
        XCTAssertTrue(app.tabBars.buttons["履歴"].exists)

        let detailAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        detailAttachment.name = "workout-detail"
        detailAttachment.lifetime = .keepAlways
        add(detailAttachment)
    }

    @MainActor
    func testWorkoutDetailEditModeScreenshot() throws {
        let historyEditExerciseID = "30000000-0000-4000-8000-000000000001"
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-history"]
        app.launch()
        waitForAppToBeStable(app)

        app.tabBars.buttons["履歴"].tap()
        let historyRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "workout-history-row-")
        ).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        historyRow.tap()

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
        XCTAssertTrue(app.staticTexts["100 kg"].exists)

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

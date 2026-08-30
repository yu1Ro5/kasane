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
    func testAddedExerciseAppearsWithoutReopeningWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let startButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        let addExerciseButton = app.buttons["種目を追加"].firstMatch
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10))
        addExerciseButton.tap()

        let exercise = app.buttons["ダンベルカール"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 10))
        exercise.tap()

        XCTAssertTrue(app.navigationBars["ワークアウト"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["ダンベルカール"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testWorkoutWeightInputScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-three-exercises"]
        app.launch()
        waitForAppToBeStable(app)

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))
        resumeButton.tap()

        let weightInput = app.textFields.matching(identifier: "draft-weight-input").firstMatch
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        weightInput.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-weight-input"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutCancelConfirmationScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-three-exercises"]
        app.launch()
        waitForAppToBeStable(app)

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))
        resumeButton.tap()

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

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-cancel-confirmation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutEmptyCancelConfirmationScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-three-exercises"]
        app.launch()
        waitForAppToBeStable(app)

        let resumeButton = app.buttons["workout-resume-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 10))
        resumeButton.tap()

        let finishButton = app.buttons["終了"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10))
        finishButton.tap()
        XCTAssertTrue(
            app.staticTexts["完了済みとして保存せず、このワークアウトを中止します。"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["中止する"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-empty-cancel-confirmation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutHistoryScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-history"]
        app.launch()
        waitForAppToBeStable(app)

        let historyTab = app.tabBars.buttons["履歴"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 10))
        historyTab.tap()
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン、ほか1種目"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-history"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testWorkoutDetailScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture", "workout-history"]
        app.launch()
        waitForAppToBeStable(app)

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

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-detail"
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

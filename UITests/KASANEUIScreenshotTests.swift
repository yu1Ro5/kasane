import XCTest

final class KASANEUIScreenshotTests: XCTestCase {
    @MainActor
    func testEmptyScreenshots() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["概要"].exists)
        XCTAssertTrue(app.tabBars.buttons["ワークアウト"].exists)
        XCTAssertTrue(app.staticTexts["今月の積み重ね"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-calendar"].exists)
        XCTAssertFalse(app.buttons["履歴"].exists)
        XCTAssertFalse(app.tabBars.buttons["履歴"].exists)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-empty"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.tabBars.buttons["ワークアウト"].tap()

        let startButton = app.buttons["workout-start-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        XCTAssertEqual(startButton.label, "ワークアウトを開始")

        let workoutAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        workoutAttachment.name = "workout-root-empty"
        workoutAttachment.lifetime = .keepAlways
        add(workoutAttachment)

        startButton.tap()
        XCTAssertTrue(app.staticTexts["今回のワークアウト"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["すべての種目"].exists)
        XCTAssertFalse(app.navigationBars["ワークアウト"].buttons["ワークアウト"].exists)
    }

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
    func testOverviewScreenshots() throws {
        let app = launchApp(additionalArguments: ["--fixture", "overview-recent-workouts"])

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["overview-workout-count"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-duration"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-total-volume"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-streak"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["overview-monthly-insight-card"].waitForExistence(
                timeout: 10
            )
        )
        XCTAssertFalse(
            app.buttons["overview-recent-workout-row-\(overviewOldestSessionID)"].exists
        )
        XCTAssertFalse(app.staticTexts["アクティブテスト種目"].exists)
        XCTAssertTrue(app.tabBars.buttons["概要"].exists)
        XCTAssertTrue(app.tabBars.buttons["ワークアウト"].exists)

        // 種目カードより先にある既存セクションを、画面高に依存せず検証する。
        XCTAssertTrue(scrollToHittable(app.staticTexts["最近のワークアウト"], in: app))
        XCTAssertTrue(app.staticTexts["ベンチプレス、ラットプルダウン"].exists)
        let recentWorkoutsAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        recentWorkoutsAttachment.name = "overview-recent-workouts"
        recentWorkoutsAttachment.lifetime = .keepAlways
        add(recentWorkoutsAttachment)

        let allExercises = app.buttons["overview-all-exercise-records"]
        XCTAssertTrue(scrollToHittable(allExercises, in: app))
        XCTAssertTrue(allExercises.exists)

        let benchCard = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "overview-exercise-card-",
                "ベンチプレス"
            )
        ).firstMatch
        XCTAssertTrue(scrollToHittable(benchCard, in: app))
        XCTAssertTrue(benchCard.label.contains("自己ベスト"))

        XCTAssertTrue(allExercises.waitForExistence(timeout: 5))
        allExercises.tap()
        XCTAssertTrue(app.descendants(matching: .any)["exercise-records-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                    "exercise-record-list-row-",
                    "プランク"
                )
            ).firstMatch.exists
        )
        app.navigationBars["すべての種目"].buttons["概要"].tap()

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
        let app = launchApp(additionalArguments: ["--fixture", "overview-previous-month"])

        XCTAssertTrue(app.descendants(matching: .any)["overview-workout-count"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["最近のワークアウト"].exists)
        XCTAssertTrue(app.staticTexts["デッドリフト"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["overview-month-selector"].exists)
        app.descendants(matching: .any)["overview-month-selector"].tap()
        app.buttons["2026年8月"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["overview-monthly-insight-card"].waitForExistence(
                timeout: 10
            )
        )

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "overview-previous-month"
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
    func testWorkoutInteractionScreenshots() throws {
        let app = launchApp(additionalArguments: ["--fixture", "workout-set-layout"])

        app.tabBars.buttons["ワークアウト"].tap()

        XCTAssertTrue(app.staticTexts["今回のワークアウト"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["すべての種目"].exists)
        XCTAssertTrue(app.buttons["終了"].exists)
        XCTAssertFalse(app.buttons["ワークアウトを再開"].exists)
        XCTAssertFalse(app.navigationBars["ワークアウト"].buttons["ワークアウト"].exists)

        let shouldersHeader = app.buttons["workout-body-part-shoulders"]
        let shoulderPress = app.buttons[
            "available-exercise-\(workoutShoulderPressExerciseID)"
        ]
        XCTAssertTrue(shouldersHeader.waitForExistence(timeout: 10))
        XCTAssertFalse(shoulderPress.exists)

        let activeRootAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        activeRootAttachment.name = "workout-root-active"
        activeRootAttachment.lifetime = .keepAlways
        add(activeRootAttachment)

        shouldersHeader.tap()
        XCTAssertTrue(shoulderPress.waitForExistence(timeout: 5))
        shouldersHeader.tap()
        XCTAssertTrue(shoulderPress.waitForNonExistence(timeout: 5))

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
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)

        app.buttons["次へ"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)
        let repsInput = app.textFields["draft-reps-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(repsInput.waitForExistence(timeout: 5))
        repsInput.typeText("8")

        let weightInputAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        weightInputAttachment.name = "workout-weight-input"
        weightInputAttachment.lifetime = .keepAlways
        add(weightInputAttachment)
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(weightInput.waitForExistence(timeout: 5))
        XCTAssertEqual(weightInput.value as? String, "0")
        XCTAssertEqual(repsInput.value as? String, "0")
        XCTAssertEqual(app.buttons.matching(identifier: "次へ").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "完了").count, 1)

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
        XCTAssertTrue(shoulderPress.exists)
        XCTAssertFalse(shouldersHeader.exists)

        let searchAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        searchAttachment.name = "workout-exercise-search"
        searchAttachment.lifetime = .keepAlways
        add(searchAttachment)
    }

    @MainActor
    func testWorkoutValidationAndCompletionScreenshots() throws {
        let app = launchApp(additionalArguments: ["--fixture", "workout-set-layout"])

        app.tabBars.buttons["ワークアウト"].tap()
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

        XCTAssertTrue(app.staticTexts["NEW RECORD"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["ワークアウト"].exists)
        app.buttons["personal-record-continue-button"].tap()
        XCTAssertTrue(app.staticTexts["今日も積み重ねました"].waitForExistence(timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let completedAttachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        completedAttachment.name = "workout-completed"
        completedAttachment.lifetime = .keepAlways
        add(completedAttachment)
    }

    @MainActor
    func testWorkoutCompletionInsightScreenshot() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "workout-set-layout", "--workout-insight-fixture",
        ])
        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["終了"].tap()
        XCTAssertTrue(app.buttons["終了して保存"].waitForExistence(timeout: 5))
        app.buttons["終了して保存"].tap()

        XCTAssertTrue(app.staticTexts["NEW RECORD"].waitForExistence(timeout: 10))
        app.buttons["personal-record-continue-button"].tap()
        let insightCard = app.descendants(matching: .any)["workout-insight-card"]
        XCTAssertTrue(insightCard.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["完了"].isEnabled)

        let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
        attachment.name = "workout-completed-insight"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPersonalRecordScreenshotsAndCompletionNavigation() throws {
        for appearance in ["light", "dark"] {
            let app = launchApp(
                additionalArguments: [
                    "--fixture", "personal-record", "-AppleInterfaceStyle", appearance,
                ]
            )
            app.tabBars.buttons["ワークアウト"].tap()
            app.buttons["終了"].tap()
            XCTAssertTrue(app.buttons["終了して保存"].waitForExistence(timeout: 5))
            app.buttons["終了して保存"].tap()

            XCTAssertTrue(app.staticTexts["NEW RECORD"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["レッグプレス"].exists)
            XCTAssertTrue(app.staticTexts["72.00 kg"].exists)
            XCTAssertTrue(app.staticTexts["Previous"].exists)
            XCTAssertTrue(app.staticTexts["前回より +9.00 kg"].exists)
            XCTAssertFalse(app.tabBars.buttons["ワークアウト"].exists)

            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            let attachment = XCTAttachment(screenshot: takeStableScreenshot(app))
            attachment.name = "personal-record-\(appearance)"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.buttons["personal-record-continue-button"].tap()
            XCTAssertTrue(app.staticTexts["今日も積み重ねました"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    @MainActor
    func testWorkoutPreviousRecordScreenshots() throws {
        let app = launchApp(additionalArguments: ["--fixture", "workout-set-layout"])

        app.tabBars.buttons["ワークアウト"].tap()
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

    @MainActor
    func testWorkoutHistoryScreenshots() throws {
        let app = launchApp(additionalArguments: ["--fixture", "workout-history"])

        let historyLink = app.buttons["すべて見る"]
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

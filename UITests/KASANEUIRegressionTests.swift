import XCTest

final class KASANEUIRegressionTests: XCTestCase {
    @MainActor
    func testDataManagementNavigationAndActions() throws {
        let app = launchApp()
        app.buttons["KASANEについて"].tap()

        let dataManagement = app.descendants(matching: .any)["data-management-link"]
        XCTAssertTrue(dataManagement.waitForExistence(timeout: 10))
        dataManagement.tap()

        XCTAssertTrue(app.navigationBars["データ管理"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["icloud-backup-section"].exists)
        XCTAssertTrue(app.buttons["icloud-backup"].exists)
        XCTAssertTrue(app.buttons["icloud-restore"].exists)
        XCTAssertTrue(app.buttons["backup-export"].exists)
        XCTAssertTrue(app.buttons["backup-import"].exists)
    }

    /// 最近のワークアウトから詳細を開き、概要へ戻れることを確認する。
    @MainActor
    func testOverviewRecentWorkoutOpensDetail() throws {
        let app = launchApp(additionalArguments: ["--fixture", "overview-recent-workouts"])
        let recentRow = app.buttons["overview-recent-workout-row-\(overviewNewestSessionID)"]
        XCTAssertTrue(scrollToHittable(recentRow, in: app))
        recentRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-detail-view"].waitForExistence(timeout: 10)
        )

        app.navigationBars["ワークアウト詳細"].buttons["概要"].tap()
        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
    }

    /// 検索結果の詳細を表示した後も検索語を保持することを確認する。
    @MainActor
    func testOverviewSearchKeepsQueryAfterViewingDetail() throws {
        let app = launchApp(additionalArguments: ["--fixture", "overview-recent-workouts"])
        let searchButton = app.buttons["検索"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 10))
        searchButton.tap()

        let searchField = app.searchFields["種目名を検索"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
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
        XCTAssertEqual(searchField.value as? String, "デッドリフト")
    }

    /// 履歴のスワイプ削除後は、対象ワークアウトが一覧から消えることを確認する。
    @MainActor
    func testCompletedWorkoutDeletionFlow() throws {
        let app = launchApp(additionalArguments: ["--fixture", "overview-recent-workouts"])

        let showAllButton = app.buttons["すべて見る"]
        XCTAssertTrue(scrollToHittable(showAllButton, in: app))
        showAllButton.tap()
        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 10))

        let historyRow = app.buttons["workout-history-row-\(overviewOldestSessionID)"]
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10))
        historyRow.swipeLeft()
        let swipeDeleteButton = app.buttons["delete-workout-\(overviewOldestSessionID)"]
        XCTAssertTrue(swipeDeleteButton.waitForExistence(timeout: 5))
        swipeDeleteButton.tap()

        app.buttons["削除"].tap()

        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 10))
        XCTAssertFalse(historyRow.exists)
    }

    /// 回数候補が回数欄だけに表示され、現在のDraftまたは保存済みSetだけを置換することを確認する。
    @MainActor
    func testWorkoutRepSuggestionsApplyToFocusedInput() throws {
        let app = launchApp(additionalArguments: ["--fixture", "workout-set-layout"])
        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["current-exercise-\(workoutSeatedRowExerciseID)"].tap()

        let draftWeight = app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
        let draftReps = app.textFields["draft-reps-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(draftWeight.waitForExistence(timeout: 10))
        draftWeight.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["rep-suggestion-10"].exists)
        XCTAssertTrue(app.buttons["次へ"].exists)
        XCTAssertTrue(app.buttons["完了"].exists)

        draftReps.tap()
        for reps in [10, 8, 12, 15] {
            XCTAssertTrue(app.buttons["rep-suggestion-\(reps)"].waitForExistence(timeout: 5))
        }
        app.buttons["rep-suggestion-12"].tap()
        XCTAssertEqual(draftReps.value as? String, "12")
        app.buttons["rep-suggestion-10"].tap()
        XCTAssertEqual(draftReps.value as? String, "10")

        let savedReps = app.textFields.matching(
            NSPredicate(format: "label == 'セット1の回数'")
        ).firstMatch
        XCTAssertTrue(savedReps.exists)
        savedReps.tap()
        app.buttons["rep-suggestion-12"].tap()
        XCTAssertEqual(savedReps.value as? String, "12")
        XCTAssertEqual(draftReps.value as? String, "10")
        XCTAssertTrue(app.buttons["次へ"].exists)
        XCTAssertTrue(app.buttons["完了"].exists)
    }

    @MainActor
    func testWorkoutCompletionWithoutImprovementOmitsInsight() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "workout-insight-no-improvement", "--workout-insight-fixture",
        ])
        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["終了"].tap()
        XCTAssertTrue(app.buttons["終了して保存"].waitForExistence(timeout: 5))
        app.buttons["終了して保存"].tap()

        XCTAssertTrue(app.staticTexts["今日も積み重ねました"].waitForExistence(timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertFalse(app.descendants(matching: .any)["workout-insight-card"].exists)
        XCTAssertTrue(app.buttons["完了"].isEnabled)
    }

    /// Foundation Modelsを呼ばず、固定解析結果の確認・修正・一括追加を検証する。
    @MainActor
    func testWorkoutAIQuickInputReviewAndApply() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "workout-set-layout", "--workout-ai-fixture",
        ])
        app.tabBars.buttons["ワークアウト"].tap()
        let quickInputButton = app.buttons["workout-ai-quick-input-button"]
        XCTAssertTrue(quickInputButton.waitForExistence(timeout: 10))
        quickInputButton.tap()

        let input = app.descendants(matching: .any)["workout-ai-input-text"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("チェストプレス30kgを10回3セット。ラットプル18kgを12回3セット。")
        app.buttons["workout-ai-analyze-button"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["workout-ai-review"].waitForExistence(timeout: 10)
        )
        XCTAssertEqual(app.staticTexts.matching(identifier: "チェストプレス").count, 1)
        XCTAssertEqual(app.staticTexts.matching(identifier: "ラットプルダウン").count, 1)
        XCTAssertEqual(app.textFields.matching(NSPredicate(format: "label CONTAINS 'の回数'")).count, 6)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.buttons["workout-ai-apply-button"].exists)

        let firstReps = app.textFields["セット1の回数"].firstMatch
        XCTAssertTrue(firstReps.waitForExistence(timeout: 5))
        firstReps.tap()
        firstReps.typeText(String(XCUIKeyboardKey.delete.rawValue) + "9")
        app.buttons["完了"].tap()

        let applyButton = app.buttons["workout-ai-apply-button"]
        XCTAssertTrue(applyButton.isEnabled)
        applyButton.tap()

        XCTAssertTrue(app.navigationBars["ワークアウト"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["チェストプレス"].exists)
        XCTAssertTrue(app.staticTexts["ラットプルダウン"].exists)
    }

    /// AI Draftへ空のSetを追加し、入力後の一括反映を検証する。
    @MainActor
    func testWorkoutAIQuickInputAddsSetBeforeApply() throws {
        let app = launchAIQuickInputReview()
        let originalWeightCount = app.textFields.matching(
            NSPredicate(format: "label CONTAINS 'の重量kg'")
        ).count

        let addSet = app.buttons.matching(NSPredicate(format: "label == 'セットを追加'")).firstMatch
        XCTAssertTrue(addSet.waitForExistence(timeout: 5))
        addSet.tap()

        let weightFields = app.textFields.matching(NSPredicate(format: "label CONTAINS 'の重量kg'"))
        XCTAssertEqual(weightFields.count, originalWeightCount + 1)
        let weight = weightFields.element(boundBy: 3)
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.typeText("35")
        XCTAssertEqual(weight.value as? String, "35")
        app.buttons["次へ"].tap()
        let repsFields = app.textFields.matching(NSPredicate(format: "label CONTAINS 'の回数'"))
        repsFields.element(boundBy: 3).typeText("8")
        app.buttons["完了"].tap()
        app.buttons["workout-ai-apply-button"].tap()

        XCTAssertTrue(app.navigationBars["ワークアウト"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["チェストプレス"].exists)
    }

    /// AI Draftへ既存Catalogの種目とSetを追加してから一括反映できることを検証する。
    @MainActor
    func testWorkoutAIQuickInputAddsExerciseBeforeApply() throws {
        let app = launchAIQuickInputReview()
        let addSetButtons = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "workout-ai-add-set-"
            )
        )
        let existingAddSetIDs = Set(
            addSetButtons.allElementsBoundByIndex.map(\.identifier)
        )

        let addExerciseButton = app.descendants(matching: .any)["workout-ai-add-exercise-button"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5))
        addExerciseButton.tap()
        let exerciseChoice = app.descendants(matching: .any)["デッドリフト"]
        XCTAssertTrue(exerciseChoice.waitForExistence(timeout: 5))
        exerciseChoice.tap()
        XCTAssertTrue(app.staticTexts["デッドリフト"].waitForExistence(timeout: 5))

        let addSetDeadline = Date().addingTimeInterval(5)
        while addSetButtons.count != existingAddSetIDs.count + 1, Date() < addSetDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let newAddSetButton = try XCTUnwrap(
            addSetButtons.allElementsBoundByIndex.first {
                !existingAddSetIDs.contains($0.identifier)
            }
        )
        var scrollAttempts = 0
        while !newAddSetButton.isHittable && scrollAttempts < 4 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(
            newAddSetButton.isHittable,
            "追加したExerciseのセット追加ボタンが操作可能になること"
        )

        let weightFields = app.textFields.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "workout-ai-weight-"
            )
        )
        let existingWeightIDs = Set(
            weightFields.allElementsBoundByIndex.map(\.identifier)
        )
        app.swipeUp()
        newAddSetButton.tap()

        let weightDeadline = Date().addingTimeInterval(5)
        while weightFields.count != existingWeightIDs.count + 1, Date() < weightDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(
            weightFields.count,
            7,
            "Set追加後、重量入力欄が6個から7個へ増えること"
        )
        guard weightFields.count == 7 else { return }
        let newWeight = try XCTUnwrap(
            weightFields.allElementsBoundByIndex.first {
                !existingWeightIDs.contains($0.identifier)
            }
        )
        XCTAssertTrue(newWeight.waitForExistence(timeout: 5))
        newWeight.typeText("60")

        let setID = newWeight.identifier.replacingOccurrences(
            of: "workout-ai-weight-",
            with: ""
        )
        let reps = app.textFields["workout-ai-reps-\(setID)"]
        app.buttons["次へ"].tap()
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.typeText("5")
        app.buttons["完了"].tap()
        app.buttons["workout-ai-apply-button"].tap()

        XCTAssertTrue(app.navigationBars["ワークアウト"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts.matching(identifier: "デッドリフト").count, 1)
    }

    /// Foundation Modelsを呼ばず、分類済み解析エラーのAlert文言を検証する。
    @MainActor
    func testWorkoutAIQuickInputShowsClassifiedError() throws {
        let app = launchApp(additionalArguments: [
            "--fixture", "workout-set-layout", "--workout-ai-fixture",
            "--workout-ai-error-fixture",
        ])
        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["workout-ai-quick-input-button"].tap()

        let input = app.descendants(matching: .any)["workout-ai-input-text"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("チェストプレス30kgを10回3セット。")
        app.buttons["workout-ai-analyze-button"].tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        XCTAssertTrue(app.alerts["AI入力を完了できませんでした"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["AIを一時的に利用できません。少し待ってから再度お試しください。"].exists
        )
    }

    @MainActor
    func testOverviewPreviousMonthNavigation() throws {
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
    }

    @MainActor
    func testWorkoutCompletionInsightAppears() throws {
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
    }

    @MainActor
    func testPersonalRecordCompletionNavigation() throws {
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

            app.buttons["personal-record-continue-button"].tap()
            XCTAssertTrue(app.staticTexts["今日も積み重ねました"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    @MainActor
    func testWorkoutPreviousRecordState() throws {
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

        app.navigationBars.buttons["ワークアウト"].tap()
        app.buttons["current-exercise-\(workoutNoPreviousExerciseID)"].tap()
        let noPreviousWeightInput = app.textFields["draft-weight-input-\(workoutNoPreviousEntryID)"]
        XCTAssertTrue(noPreviousWeightInput.waitForExistence(timeout: 10))
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "previous-workout-record-\(workoutNoPreviousExerciseID)"
            ].exists
        )
    }

    @MainActor
    private func launchAIQuickInputReview() -> XCUIApplication {
        let app = launchApp(additionalArguments: [
            "--fixture", "workout-set-layout", "--workout-ai-fixture",
        ])
        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["workout-ai-quick-input-button"].tap()
        let input = app.descendants(matching: .any)["workout-ai-input-text"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("チェストプレス30kgを10回3セット。ラットプル18kgを12回3セット。")
        app.buttons["workout-ai-analyze-button"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workout-ai-review"].waitForExistence(timeout: 10)
        )
        return app
    }
}

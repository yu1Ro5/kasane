import XCTest

final class KASANEUISmokeTests: XCTestCase {
    /// アプリの主要画面を起動し、ワークアウトを開始できることを確認する。
    @MainActor
    func testAppLaunchSmoke() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["概要"].waitForExistence(timeout: 10))
        app.tabBars.buttons["ワークアウト"].tap()

        let startButton = app.buttons["workout-start-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        XCTAssertTrue(app.staticTexts["今回のワークアウト"].waitForExistence(timeout: 10))
    }

    /// セット入力からワークアウト完了までの中心的な経路を確認する。
    @MainActor
    func testWorkoutHappyPathSmoke() throws {
        let app = launchApp(additionalArguments: ["--fixture", "workout-set-layout"])

        app.tabBars.buttons["ワークアウト"].tap()
        let currentExercise = app.buttons["current-exercise-\(workoutSeatedRowExerciseID)"]
        XCTAssertTrue(currentExercise.waitForExistence(timeout: 10))
        currentExercise.tap()

        let weightInput = app.textFields["draft-weight-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(weightInput.waitForExistence(timeout: 10))
        let savedSetWeightFields = app.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "saved-set-weight-input-")
        )
        let savedSetCount = savedSetWeightFields.count
        weightInput.tap()
        weightInput.typeText("50")
        app.buttons["次へ"].tap()

        let repsInput = app.textFields["draft-reps-input-\(workoutSeatedRowEntryID)"]
        XCTAssertTrue(repsInput.waitForExistence(timeout: 5))
        repsInput.typeText("8")
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let saveDeadline = Date().addingTimeInterval(5)
        while savedSetWeightFields.count != savedSetCount + 1, Date() < saveDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(savedSetWeightFields.count, savedSetCount + 1)
        app.buttons["完了"].tap()

        app.navigationBars.buttons["ワークアウト"].tap()
        let finishButton = app.buttons["終了"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10))
        finishButton.tap()

        let saveButton = app.buttons["終了して保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["NEW RECORD"].waitForExistence(timeout: 10))
        app.buttons["personal-record-continue-button"].tap()
        XCTAssertTrue(app.staticTexts["今日も積み重ねました"].waitForExistence(timeout: 10))
    }

    /// 種目追加中の入力Draftが画面移動後も保持されることを確認する。
    @MainActor
    func testWorkoutDraftPersistsAcrossNavigation() throws {
        let app = launchApp(additionalArguments: ["--fixture", "workout-set-layout"])
        app.tabBars.buttons["ワークアウト"].tap()
        let searchField = app.searchFields["種目名を検索"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("ショルダー")

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
}

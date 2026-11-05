import XCTest

final class ExerciseManagementUITests: XCTestCase {
    @MainActor
    func testSettingsAddAndCancelExerciseWithoutStartingWorkout() throws {
        let app = launchApp()
        app.buttons["設定"].tap()
        app.buttons["exercise-management-link"].tap()
        XCTAssertTrue(app.navigationBars["種目管理"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ベンチプレス"].exists)
        app.buttons["exercise-add-button"].tap()
        XCTAssertFalse(app.buttons["exercise-save-button"].isEnabled)
        let field = app.textFields["exercise-name-field"]
        field.tap()
        field.typeText("Custom Machine")
        app.buttons["exercise-save-button"].tap()
        XCTAssertTrue(app.navigationBars["種目管理"].waitForExistence(timeout: 5))
        for _ in 0..<8 {
            if app.staticTexts["Custom Machine"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Custom Machine"].waitForExistence(timeout: 5))
        app.buttons["exercise-add-button"].tap()
        app.textFields["exercise-name-field"].tap()
        app.textFields["exercise-name-field"].typeText("Discard Machine")
        app.buttons["キャンセル"].tap()
        app.buttons["破棄する"].tap()
        XCTAssertFalse(app.staticTexts["Discard Machine"].exists)
    }
}

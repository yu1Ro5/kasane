import XCTest

final class ExerciseManagementUITests: XCTestCase {
    @MainActor
    func testFiltersEmptyStateAndArchiveRefresh() throws {
        let app = launchApp()
        app.buttons["設定"].tap()
        app.buttons["exercise-management-link"].tap()
        let filter = app.buttons["exercise-filter-button"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        XCTAssertEqual(filter.label, "種目を絞り込む：利用中")
        XCTAssertTrue(app.staticTexts["ベンチプレス"].exists)

        filter.tap()
        XCTAssertTrue(app.buttons["すべて"].exists)
        XCTAssertTrue(app.buttons["利用中"].exists)
        XCTAssertTrue(app.buttons["アーカイブ済み"].exists)
        app.buttons["アーカイブ済み"].tap()
        XCTAssertEqual(filter.label, "種目を絞り込む：アーカイブ済み")
        XCTAssertTrue(app.staticTexts["アーカイブ済みの種目はありません"].exists)
        XCTAssertFalse(app.staticTexts["ベンチプレス"].exists)

        filter.tap()
        app.buttons["すべて"].tap()
        XCTAssertEqual(filter.label, "種目を絞り込む：すべて")
        XCTAssertTrue(app.staticTexts["ベンチプレス"].exists)
        app.buttons["ベンチプレスの操作"].tap()
        app.buttons["アーカイブ"].tap()
        app.buttons["アーカイブ"].tap()
        XCTAssertTrue(app.staticTexts["アーカイブ済み"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ベンチプレス"].exists)

        filter.tap()
        app.buttons["利用中"].tap()
        XCTAssertFalse(app.staticTexts["ベンチプレス"].exists)
        filter.tap()
        app.buttons["アーカイブ済み"].tap()
        XCTAssertTrue(app.staticTexts["ベンチプレス"].exists)
        app.buttons["ベンチプレスの操作"].tap()
        app.buttons["アーカイブ解除"].tap()
        XCTAssertFalse(app.staticTexts["ベンチプレス"].exists)
        XCTAssertTrue(app.buttons["exercise-add-button"].exists)
    }

    @MainActor
    func testEditUsesSharedSheetAndAddWorksFromArchivedFilter() throws {
        let app = launchApp()
        app.buttons["設定"].tap()
        app.buttons["exercise-management-link"].tap()
        let filter = app.buttons["exercise-filter-button"]
        app.buttons["ベンチプレスの操作"].tap()
        app.buttons["編集"].tap()
        XCTAssertTrue(app.navigationBars["種目を編集"].waitForExistence(timeout: 5))
        let name = app.textFields["exercise-name-field"]
        XCTAssertEqual(name.value as? String, "ベンチプレス")
        XCTAssertTrue(app.buttons["exercise-save-button"].isEnabled)
        app.buttons["キャンセル"].tap()

        filter.tap()
        app.buttons["アーカイブ済み"].tap()
        app.buttons["exercise-add-button"].tap()
        XCTAssertTrue(app.navigationBars["種目を追加"].waitForExistence(timeout: 5))
        let newName = app.textFields["exercise-name-field"]
        newName.tap()
        newName.typeText("追加した種目")
        app.buttons["exercise-save-button"].tap()
        XCTAssertEqual(filter.label, "種目を絞り込む：利用中")
        for _ in 0..<8 {
            if app.staticTexts["追加した種目"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["追加した種目"].waitForExistence(timeout: 5))
    }

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

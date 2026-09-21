import XCTest

extension XCTestCase {
    var historySessionID: String { "50000000-0000-4000-8000-000000000001" }
    var overviewNewestSessionID: String { "40000000-0000-4000-8000-000000000001" }
    var overviewOldestSessionID: String { "40000000-0000-4000-8000-000000000004" }
    var workoutSeatedRowExerciseID: String { "00000000-0000-4000-8000-000000000006" }
    var workoutNoPreviousExerciseID: String { "20000000-0000-4000-8000-000000000002" }
    var workoutShoulderPressExerciseID: String { "00000000-0000-4000-8000-000000000009" }
    var workoutSeatedRowEntryID: String { "21000000-0000-4000-8000-000000000001" }
    var workoutNoPreviousEntryID: String { "21000000-0000-4000-8000-000000000002" }

    /// 日本語表示のUIテストとしてアプリを起動し、最初のウィンドウが安定するまで待機する。
    @MainActor
    func launchApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments =
            [
                "--ui-testing",
                "-AppleLanguages", "(ja)",
                "-AppleLocale", "ja_JP",
            ] + additionalArguments
        app.launch()
        waitForAppToBeStable(app)
        return app
    }

    /// 最前面ウィンドウのフレームが有限かつゼロでない状態になるまで待機する。
    @MainActor
    func waitForAppToBeStable(_ app: XCUIApplication, timeout: TimeInterval = 5.0) {
        let window = app.windows.firstMatch
        if !window.exists {
            XCTAssertTrue(window.waitForExistence(timeout: timeout))
        }

        let deadline = Date().addingTimeInterval(timeout)
        var lastFrame = CGRect.null
        repeat {
            let frame = window.frame
            if frame.isFiniteNonZero { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            lastFrame = frame
        } while Date() < deadline

        XCTAssertTrue(window.frame.isFiniteNonZero, "ウィンドウのフレームが安定しませんでした: \(lastFrame)")
    }

    /// UIの安定を待ってからスクリーンショットを取得する。
    @MainActor
    func takeStableScreenshot(_ app: XCUIApplication) -> XCUIScreenshot {
        waitForAppToBeStable(app)
        return XCUIScreen.main.screenshot()
    }

    /// 縦スクロールの末尾にある操作要素を、画面構成の高さに依存せず表示する。
    @MainActor
    func scrollToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 6
    ) -> Bool {
        for swipeCount in 0...maximumSwipes {
            if element.exists && element.isHittable { return true }
            if swipeCount < maximumSwipes { app.swipeUp() }
        }
        return false
    }
}

extension CGRect {
    /// フレームの幅・高さが有限かつ正であるか。
    var isFiniteNonZero: Bool {
        guard width.isFinite, height.isFinite else { return false }
        return width > 0 && height > 0
    }
}

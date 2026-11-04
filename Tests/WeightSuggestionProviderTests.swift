import Foundation
import XCTest

@testable import KASANE

final class WeightSuggestionProviderTests: XCTestCase {
    private let exerciseID = UUID()
    private let otherExerciseID = UUID()
    private let currentSessionID = UUID()

    func testCurrentPreviousIsFirstAndEditingUsesOnlyEarlierSets() {
        let sets = [SetEntryDraft(weight: "29.3"), SetEntryDraft(weight: "22.6"), SetEntryDraft()]
        let history = [workout(day: 2, weights: [40, 40])]
        XCTAssertEqual(suggestions(history, at: 1, sets: sets).first, "29.3")
        XCTAssertEqual(suggestions(history, at: 2, sets: sets).first, "22.6")
        XCTAssertEqual(suggestions(history, at: 3, sets: sets).first, "22.6")
        XCTAssertEqual(sets[2].weight, "")
    }

    func testInvalidEarlierDraftUsesEarlierValidSetThenHistory() {
        let sets = [SetEntryDraft(weight: "29.3"), SetEntryDraft(weight: "bad")]
        let history = [workout(weights: [22.6, .nan])]
        XCTAssertEqual(suggestions(history, at: 2, sets: sets).first, "29.3")
        XCTAssertEqual(suggestions(history).first, "22.6")
    }

    func testEarlierCompletedWorkoutSuppliesPreviousWhenNewestHasNoValidSet() {
        let history = [workout(day: 2, weights: [.nan]), workout(day: 1, weights: [29.3])]
        XCTAssertEqual(suggestions(history).first, "29.3")
    }

    func testNoHistoryAndNearestDefaults() {
        XCTAssertEqual(suggestions([]), ["5", "10", "15", "20"])
        XCTAssertEqual(
            suggestions([], at: 1, sets: [SetEntryDraft(weight: "22.6")]),
            ["22.6", "25", "20", "30"]
        )
    }

    func testScoresUseRecencyAndSetFrequency() {
        let history = [workout(day: 1, weights: [11, 11, 11]), workout(day: 2, weights: [22, 22])]
        let sets = [SetEntryDraft(weight: "99")]
        XCTAssertEqual(Array(suggestions(history, at: 1, sets: sets).prefix(3)), ["99", "11", "22"])
    }

    func testOnlyTenMatchingCompletedWorkoutsCount() {
        var history = (1...10).map { workout(day: $0, weights: [30]) }
        history.append(workout(day: 0, weights: Array(repeating: 99, count: 30)))
        history.append(workout(day: 11, ended: false, weights: [88]))
        history.append(workout(day: 12, exerciseID: otherExerciseID, weights: [77]))
        // 30kgから同距離の20kgと40kgは、小さい20kgを先に補完する。
        XCTAssertEqual(suggestions(history), ["30", "25", "20", "40"])
    }

    func testNumericTieOrderAndDuplicateFormatting() {
        XCTAssertEqual(suggestions([workout(weights: [30, 30.0, 29.3, 22.6])]),
                       ["22.6", "30", "29.3", "25"])
    }

    func testInvalidValuesAndLocale() {
        let result = suggestions([workout(weights: [.nan, .infinity, -1, 0, 29.3])])
        XCTAssertEqual(result, ["29.3", "0", "30", "25"])
        XCTAssertEqual(suggestions([workout(weights: [29.3])], separator: ",").first, "29,3")
    }

    private func suggestions(
        _ workouts: [WeightSuggestionWorkout], at index: Int = 0,
        sets: [SetEntryDraft] = [], separator: String = "."
    ) -> [String] {
        WeightSuggestionProvider.suggestions(
            for: exerciseID, currentSessionID: currentSessionID, workouts: workouts,
            at: index, currentSets: sets, decimalSeparator: separator
        )
    }

    private func workout(
        day: Int = 1, ended: Bool = true, exerciseID: UUID? = nil,
        weights: [Double]
    ) -> WeightSuggestionWorkout {
        let date = Date(timeIntervalSince1970: TimeInterval(day * 86_400))
        return WeightSuggestionWorkout(
            sessionID: UUID(), startedAt: date,
            endedAt: ended ? date.addingTimeInterval(3_600) : nil,
            exerciseID: exerciseID ?? self.exerciseID, values: weights
        )
    }
}

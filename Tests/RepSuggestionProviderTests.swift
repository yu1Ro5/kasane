import Foundation
import XCTest

@testable import KASANE

final class RepSuggestionProviderTests: XCTestCase {
    private let exerciseID = UUID()
    private let otherExerciseID = UUID()
    private let currentSessionID = UUID()

    func testNoHistoryUsesDefaults() {
        XCTAssertEqual(suggestions(from: []), [8, 10, 12, 15])
    }

    func testSuggestionsAreRankedBySetFrequency() {
        XCTAssertEqual(suggestions(from: [workout(reps: [10, 10, 10, 8, 8, 12, 15])]), [15, 10, 8, 12])
    }

    func testEqualFrequencyUsesMostRecentWorkout() {
        let older = workout(day: 1, reps: [8, 8])
        let newer = workout(day: 2, reps: [12, 12])

        XCTAssertEqual(Array(suggestions(from: [older, newer]).prefix(2)), [12, 8])
    }

    func testEqualFrequencyAndRecencyUsesAscendingValue() {
        XCTAssertEqual(Array(suggestions(from: [workout(reps: [12, 8])]).prefix(2)), [8, 12])
    }

    func testHistoryIsCompletedWithNonDuplicateDefaults() {
        XCTAssertEqual(suggestions(from: [workout(reps: [10, 10, 8])]), [8, 10, 12, 15])
    }

    func testSuggestionsContainNoDuplicates() {
        let result = suggestions(from: [workout(reps: [8, 8, 10])])

        XCTAssertEqual(Set(result).count, result.count)
    }

    func testSuggestionsAreLimitedToFourValues() {
        XCTAssertEqual(suggestions(from: [workout(reps: [1, 2, 3, 4, 5])]).count, 4)
    }

    func testIncompleteWorkoutIsExcluded() {
        XCTAssertEqual(
            suggestions(from: [workout(ended: false, reps: [20])]),
            [8, 10, 12, 15]
        )
    }

    func testCurrentWorkoutIsExcluded() {
        XCTAssertEqual(
            suggestions(from: [workout(sessionID: currentSessionID, reps: [20])]),
            [8, 10, 12, 15]
        )
    }

    func testOtherExerciseIsExcluded() {
        XCTAssertEqual(
            suggestions(from: [workout(exerciseID: otherExerciseID, reps: [20])]),
            [8, 10, 12, 15]
        )
    }

    func testNonPositiveRepsAreExcluded() {
        XCTAssertEqual(suggestions(from: [workout(reps: [0, -1])]), [8, 10, 12, 15])
    }

    func testCurrentPreviousIsFirstAndInvalidDraftIsSkipped() {
        let sets = [SetEntryDraft(reps: "12"), SetEntryDraft(reps: "bad"), SetEntryDraft()]
        XCTAssertEqual(suggestions(from: [workout(reps: [10, 10])], at: 2, sets: sets).first, 12)
        XCTAssertEqual(suggestions(from: [workout(reps: [10, 10])], at: 3, sets: sets).first, 12)
    }

    func testRecentWorkoutOutscoresOlderMoreFrequentValue() {
        let older = workout(day: 1, reps: [8, 8, 8])
        let newer = workout(day: 2, reps: [12, 12, 12])
        XCTAssertEqual(Array(suggestions(from: [older, newer]).prefix(2)), [12, 8])
    }

    func testScoreAndRecencyTieUsesSetCount() {
        let history = [
            workout(day: 7, reps: [21, 22]),
            workout(day: 6, reps: []),
            workout(day: 5, reps: [21]),
            workout(day: 4, reps: []),
            workout(day: 3, reps: []),
            workout(day: 2, reps: []),
            workout(day: 1, reps: [22, 22]),
        ]
        let sets = [SetEntryDraft(reps: "99")]
        XCTAssertEqual(suggestions(from: history, at: 1, sets: sets), [99, 22, 21, 8])
    }

    func testScoreTieUsesMostRecentWorkout() {
        let history = [
            workout(day: 4, reps: [21]),
            workout(day: 3, reps: [22]),
            workout(day: 2, reps: [22]),
            workout(day: 1, reps: [21]),
        ]
        let sets = [SetEntryDraft(reps: "99")]
        XCTAssertEqual(Array(suggestions(from: history, at: 1, sets: sets).prefix(3)), [99, 21, 22])
    }

    func testEqualScoreAndRecencyUsesAscendingValue() {
        let sets = [SetEntryDraft(reps: "99")]
        XCTAssertEqual(Array(suggestions(from: [workout(reps: [12, 8])], at: 1, sets: sets).prefix(3)),
                       [99, 8, 12])
    }

    func testLastValidHistoricalSetIsFirst() {
        XCTAssertEqual(suggestions(from: [workout(reps: [8, 12, 0])]).first, 12)
    }

    func testSameDateUsesStableSessionIDOrder() {
        guard let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        else { return XCTFail("Invalid test UUID") }
        let first = workout(sessionID: firstID, reps: [21])
        let second = workout(sessionID: secondID, reps: [22])
        XCTAssertEqual(suggestions(from: [second, first]).first, 21)
    }

    func testOnlyTenMostRecentWorkoutsAreCounted() {
        var workouts = (1...10).map { workout(day: $0, reps: [8]) }
        workouts.append(workout(day: 0, reps: Array(repeating: 20, count: 30)))

        XCTAssertEqual(suggestions(from: workouts), [8, 10, 12, 15])
    }

    private func suggestions(from workouts: [RepSuggestionWorkout], at index: Int = 0, sets: [SetEntryDraft] = []) -> [Int] {
        RepSuggestionProvider.suggestions(
            for: exerciseID,
            currentSessionID: currentSessionID,
            workouts: workouts, at: index, currentSets: sets
        )
    }

    private func workout(
        sessionID: UUID = UUID(),
        day: Int = 1,
        ended: Bool = true,
        exerciseID: UUID? = nil,
        reps: [Int]
    ) -> RepSuggestionWorkout {
        let startedAt = Date(timeIntervalSince1970: TimeInterval(day * 86_400))
        return RepSuggestionWorkout(
            sessionID: sessionID,
            startedAt: startedAt,
            endedAt: ended ? startedAt.addingTimeInterval(3_600) : nil,
            exerciseID: exerciseID ?? self.exerciseID,
            values: reps
        )
    }
}

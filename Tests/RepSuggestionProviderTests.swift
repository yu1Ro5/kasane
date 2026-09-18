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
        XCTAssertEqual(suggestions(from: [workout(reps: [10, 10, 10, 8, 8, 12, 15])]), [10, 8, 12, 15])
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
        XCTAssertEqual(suggestions(from: [workout(reps: [10, 10, 8])]), [10, 8, 12, 15])
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

    func testOnlyTwentyMostRecentWorkoutsAreCounted() {
        var workouts = (1...20).map { workout(day: $0, reps: [8]) }
        workouts.append(workout(day: 0, reps: Array(repeating: 20, count: 30)))

        XCTAssertEqual(suggestions(from: workouts), [8, 10, 12, 15])
    }

    private func suggestions(from workouts: [RepSuggestionWorkout]) -> [Int] {
        RepSuggestionProvider.suggestions(
            for: exerciseID,
            currentSessionID: currentSessionID,
            workouts: workouts
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
            reps: reps
        )
    }
}

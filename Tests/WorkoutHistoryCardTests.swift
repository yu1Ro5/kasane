import Foundation
import XCTest

@testable import KASANE

@MainActor
final class WorkoutHistoryCardTests: XCTestCase {
    /// 保存済みSetだけを数え、既存の重量×回数（負値は0）の定義を維持する。
    func testWorkoutHistorySavedSetStatistics() throws {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 4_120)
        )
        let exercise = Exercise(name: "テスト種目", primaryBodyPart: .other)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        entry.setEntries = [
            SetEntry(exerciseEntry: entry, order: 0, weightKg: 42.5, reps: 8),
            SetEntry(exerciseEntry: entry, order: 1, weightKg: 20, reps: 10, isWarmup: true),
            SetEntry(exerciseEntry: entry, order: 2, weightKg: 0, reps: 12),
            SetEntry(exerciseEntry: entry, order: 3, weightKg: -10, reps: 5),
            SetEntry(exerciseEntry: entry, order: 4, weightKg: 20, reps: -5),
        ]
        session.exerciseEntries = [entry]
        let content = try XCTUnwrap(WorkoutHistoryRowContent(session: session))
        XCTAssertEqual(content.setCount, 5)
        XCTAssertEqual(content.setCountText, "5セット")
        XCTAssertEqual(content.totalVolume, 540)
        XCTAssertEqual(content.totalVolumeText, 540.formatted(.number) + "kg")

        let empty = try XCTUnwrap(WorkoutHistoryRowContent(session: session, exerciseEntries: []))
        XCTAssertEqual(empty.setCountText, "0セット")
        XCTAssertEqual(empty.totalVolume, 0)
        XCTAssertEqual(empty.exerciseCountText, "0種目")
    }
}

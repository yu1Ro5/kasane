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
    /// 表示順ではなく登録順がばらばらでも、部位を種目順で重複なく並べる。
    func testWorkoutHistoryBodyPartsDeduplicateInExerciseOrder() throws {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 4_120)
        )
        let arms = Exercise(name: "カール", primaryBodyPart: .arms)
        let back = Exercise(name: "ロー", primaryBodyPart: .back)
        let anotherBack = Exercise(name: "プルダウン", primaryBodyPart: .back)
        let armsEntry = ExerciseEntry(workoutSession: session, exercise: arms, order: 2)
        let backEntry = ExerciseEntry(workoutSession: session, exercise: back, order: 0)
        let secondBackEntry = ExerciseEntry(workoutSession: session, exercise: anotherBack, order: 1)
        session.exerciseEntries = [armsEntry, secondBackEntry, backEntry]

        let content = try XCTUnwrap(WorkoutHistoryRowContent(session: session))
        XCTAssertEqual(content.bodyPartNames, ["背中", "腕"])
        XCTAssertEqual(content.bodyPartSummary, "背中・腕")
        XCTAssertEqual(content.exerciseCountText, "3種目")
        // 概要など別画面が使う既存の種目名サマリーも維持する。
        XCTAssertEqual(content.exerciseSummary, "ロー、プルダウン、ほか1種目")
    }

    /// 8種類の部位を勝手に短縮せずすべて表示し、未知の値は「その他」にする。
    func testWorkoutHistoryShowsAllBodyPartsWithoutTruncation() throws {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 4_120)
        )
        let entries = BodyPart.allCases.enumerated().map { index, bodyPart in
            let exercise = Exercise(name: "種目\(index)", primaryBodyPart: bodyPart)
            let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: index)
            if bodyPart == .other {
                entry.primaryBodyPartSnapshot = "unknown-body-part"
            }
            return entry
        }
        session.exerciseEntries = entries.reversed()

        let content = try XCTUnwrap(WorkoutHistoryRowContent(session: session))
        XCTAssertEqual(content.bodyPartNames, BodyPart.allCases.map(\.displayName))
        XCTAssertEqual(content.bodyPartSummary, BodyPart.allCases.map(\.displayName).joined(separator: "・"))

        let empty = try XCTUnwrap(WorkoutHistoryRowContent(session: session, exerciseEntries: []))
        XCTAssertEqual(empty.bodyPartSummary, "部位の記録なし")
        XCTAssertEqual(empty.exerciseCountText, "0種目")
    }

    /// 日付を跨いで終了しても、カレンダーと同じWorkout開始日を履歴の実施日とする。
    func testWorkoutHistoryUsesStartedAtForTrainingDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let startedAt = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 11, day: 3, hour: 23, minute: 30
        )))
        let endedAt = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 11, day: 4, hour: 0, minute: 30
        )))
        let session = WorkoutSession(startedAt: startedAt, endedAt: endedAt)

        let content = try XCTUnwrap(WorkoutHistoryRowContent(session: session))
        XCTAssertEqual(content.startedAt, startedAt)
        XCTAssertEqual(content.completedAt, endedAt)
        XCTAssertEqual(calendar.component(.day, from: content.startedAt), 3)
        XCTAssertEqual(calendar.component(.day, from: content.completedAt), 4)
        XCTAssertEqual(content.durationText, "1時間0分")
    }

}

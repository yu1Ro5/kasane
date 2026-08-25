import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class KASANETests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            WorkoutSession.self,
            Exercise.self,
            ExerciseEntry.self,
            SetEntry.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    /// テスト概要: WorkoutSessionをin-memoryストアへ保存し、再取得できることを検証する。
    /// 期待値: 取得件数が1件で、IDとメモが保存時の値に一致する。
    func testWorkoutSessionCanBeSavedAndFetched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workoutSession = WorkoutSession(startedAt: Date(timeIntervalSince1970: 100), note: "Morning")

        context.insert(workoutSession)
        try context.save()

        let workoutSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(workoutSessions.count, 1)
        XCTAssertEqual(workoutSessions.first?.id, workoutSession.id)
        XCTAssertEqual(workoutSessions.first?.note, "Morning")
    }

    /// テスト概要: WorkoutSessionからExerciseEntry、SetEntryまでのグラフを保存・取得する。
    /// 期待値: Exerciseへの参照とSetEntryの重量がRelationship経由で復元される。
    func testWorkoutSessionGraphCanBeSavedAndFetched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workoutSession = WorkoutSession()
        let exercise = Exercise(name: "Bench Press", primaryBodyPart: .chest)
        let exerciseEntry = ExerciseEntry(workoutSession: workoutSession, exercise: exercise, order: 0)
        let setEntry = SetEntry(
            exerciseEntry: exerciseEntry,
            order: 0,
            weightKg: 80,
            reps: 8
        )
        workoutSession.exerciseEntries.append(exerciseEntry)
        exerciseEntry.setEntries.append(setEntry)

        context.insert(workoutSession)
        context.insert(exercise)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(fetched.exerciseEntries.first?.exercise?.id, exercise.id)
        XCTAssertEqual(fetched.exerciseEntries.first?.setEntries.first?.weightKg, 80)
    }

    /// テスト概要: 同じExerciseを異なるWorkoutSessionのExerciseEntryから参照する。
    /// 期待値: Exerciseの逆方向Relationshipに2件のExerciseEntryが含まれる。
    func testExerciseCanBeReferencedByMultipleWorkoutSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Squat", primaryBodyPart: .legs)
        let first = ExerciseEntry(workoutSession: WorkoutSession(), exercise: exercise, order: 0)
        let second = ExerciseEntry(workoutSession: WorkoutSession(), exercise: exercise, order: 0)

        context.insert(first)
        context.insert(second)
        try context.save()

        XCTAssertEqual(exercise.exerciseEntries.count, 2)
    }

    /// テスト概要: ExerciseEntryとSetEntryを持つWorkoutSessionを削除する。
    /// 期待値: 配下の記録はcascade削除され、共有されるExerciseマスタは残る。
    func testDeletingWorkoutSessionCascadesThroughItsGraph() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workoutSession = WorkoutSession()
        let exercise = Exercise(name: "Deadlift", primaryBodyPart: .back)
        let exerciseEntry = ExerciseEntry(workoutSession: workoutSession, exercise: exercise, order: 0)
        workoutSession.exerciseEntries.append(exerciseEntry)
        exerciseEntry.setEntries.append(
            SetEntry(exerciseEntry: exerciseEntry, order: 0, weightKg: 120, reps: 5)
        )
        context.insert(workoutSession)
        context.insert(exercise)
        try context.save()

        context.delete(workoutSession)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
    }

    /// テスト概要: Exerciseの名称・部位・アーカイブ状態を保存後に変更する。
    /// 期待値: ExerciseEntryの名称・部位スナップショットとExerciseへの参照が維持される。
    func testArchivingAndRenamingExercisePreservesExerciseEntrySnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Press", primaryBodyPart: .shoulders)
        let exerciseEntry = ExerciseEntry(workoutSession: WorkoutSession(), exercise: exercise, order: 0)
        context.insert(exerciseEntry)
        try context.save()

        exercise.name = "Overhead Press"
        exercise.bodyPart = .arms
        exercise.isArchived = true
        try context.save()

        XCTAssertTrue(exercise.isArchived)
        XCTAssertEqual(exerciseEntry.exerciseNameSnapshot, "Press")
        XCTAssertEqual(exerciseEntry.bodyPartSnapshot, .shoulders)
        XCTAssertEqual(exerciseEntry.exercise?.id, exercise.id)
    }

    /// テスト概要: 進行中セッションがない状態でワークアウトを開始する。
    /// 期待値: 指定した開始時刻とnilの終了日時・メモを持つセッションが即時保存される。
    func testStartingWorkoutCreatesAndSavesActiveSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let expectedDate = Date(timeIntervalSince1970: 1_000)
        let service = WorkoutSessionService(context: context, now: { expectedDate })

        let session = try service.startOrResume()
        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutSession>()).first)

        XCTAssertEqual(session.id, fetched.id)
        XCTAssertEqual(fetched.startedAt, expectedDate)
        XCTAssertNil(fetched.endedAt)
        XCTAssertNil(fetched.note)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 進行中セッションが存在する状態で開始操作を繰り返す。
    /// 期待値: 既存セッションが返り、新しいセッションは重複作成されない。
    func testStartingWorkoutResumesExistingActiveSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existing = WorkoutSession(startedAt: Date(timeIntervalSince1970: 100))
        context.insert(existing)
        try context.save()
        let service = WorkoutSessionService(
            context: context,
            now: { Date(timeIntervalSince1970: 200) }
        )

        let resumed = try service.startOrResume()

        XCTAssertEqual(resumed.id, existing.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).count, 1)
    }

    /// テスト概要: 保存済みの進行中セッションを新しいサービスインスタンスから取得する。
    /// 期待値: 同じIDのセッションを再取得できる。
    func testActiveWorkoutCanBeFetchedAfterServiceRecreation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let saved = WorkoutSession()
        context.insert(saved)
        try context.save()

        let fetched = try WorkoutSessionService(context: context).activeSession()

        XCTAssertEqual(fetched?.id, saved.id)
    }

    /// テスト概要: 終了済みセッションのみが保存されている状態を取得する。
    /// 期待値: 終了済みセッションは進行中として返されない。
    func testFinishedWorkoutIsNotActive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(WorkoutSession(endedAt: Date()))
        try context.save()

        XCTAssertNil(try WorkoutSessionService(context: context).activeSession())
    }

    /// テスト概要: 保存済みの進行中セッションを破棄する。
    /// 期待値: セッションが削除・保存され、進行中セッションがなくなる。
    func testDiscardingWorkoutDeletesAndSavesSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = WorkoutSessionService(context: context)
        let session = try service.startOrResume()

        try service.discard(session)

        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 組み込み種目のseedを複数回実行する。
    /// 期待値: 安定したIDにより種目は重複せず、既存種目も上書きされない。
    func testSeedingBuiltInExercisesIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let custom = Exercise(name: "カスタム", primaryBodyPart: .other)
        context.insert(custom)
        try context.save()

        try ExerciseCatalogService(context: context).seed()
        try ExerciseCatalogService(context: context).seed()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, ExerciseCatalogService.builtIns.count + 1)
        XCTAssertEqual(exercises.filter { $0.name == "ベンチプレス" }.count, 1)
        XCTAssertEqual(exercises.first { $0.id == custom.id }?.name, "カスタム")
    }

    /// テスト概要: Exerciseをアーカイブする。
    /// 期待値: アーカイブ済みExerciseはpickerの選択対象にならない。
    func testArchivedExerciseIsNotSelectable() {
        let exercise = Exercise(name: "旧種目", primaryBodyPart: .other, isArchived: true)

        XCTAssertFalse(exercise.isSelectable)
    }

    /// テスト概要: セッションへ種目を順番に追加する。
    /// 期待値: 参照・スナップショット・末尾orderが保存され、空のSetEntryは作られない。
    func testAddingExerciseCreatesSavedEntryWithSnapshotAndOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let first = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let second = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        context.insert(session)
        context.insert(first)
        context.insert(second)
        try context.save()

        _ = try WorkoutExerciseService(context: context).add(first, to: session)
        let entry = try WorkoutExerciseService(context: context).add(second, to: session)

        XCTAssertEqual(entry.exercise?.id, second.id)
        XCTAssertEqual(entry.exerciseNameSnapshot, "ベンチプレス")
        XCTAssertEqual(entry.bodyPartSnapshot, .chest)
        XCTAssertEqual(entry.order, 1)
        XCTAssertTrue(entry.setEntries.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 同じ種目を同一セッションと別セッションへ追加する。
    /// 期待値: 同一セッションの重複だけが拒否される。
    func testDuplicateExerciseIsRejectedOnlyWithinSameSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstSession = WorkoutSession()
        let secondSession = WorkoutSession()
        let exercise = Exercise(name: "プランク", primaryBodyPart: .core)
        context.insert(firstSession)
        context.insert(secondSession)
        context.insert(exercise)
        try context.save()
        let service = WorkoutExerciseService(context: context)

        _ = try service.add(exercise, to: firstSession)
        XCTAssertThrowsError(try service.add(exercise, to: firstSession)) { error in
            XCTAssertEqual(error as? WorkoutExerciseError, .duplicateExercise)
        }
        XCTAssertNoThrow(try service.add(exercise, to: secondSession))
    }

    /// テスト概要: 中間のExerciseEntryを削除する。
    /// 期待値: 対象が削除され、残る種目のorderが0始まりの連番になる。
    func testDeletingExerciseEntryRenumbersRemainingEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercises = (0..<3).map { Exercise(name: "種目\($0)", primaryBodyPart: .other) }
        context.insert(session)
        exercises.forEach(context.insert)
        try context.save()
        let service = WorkoutExerciseService(context: context)
        let entries = try exercises.map { try service.add($0, to: session) }

        try service.delete(entries[1], from: session)

        let remaining = try context.fetch(FetchDescriptor<ExerciseEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(remaining.map(\.exerciseNameSnapshot), ["種目0", "種目2"])
        XCTAssertEqual(remaining.map(\.order), [0, 1])
        XCTAssertFalse(context.hasChanges)
    }
}

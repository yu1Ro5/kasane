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

    /// テスト概要: 保存済みセットを持つセッションを終了する。
    /// 期待値: 終了日時が保存され、完了サマリーの時間・種目数・セット数が一致する。
    func testFinishingWorkoutSavesEndedAtAndReturnsSummary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = Date(timeIntervalSince1970: 4_900)
        let session = WorkoutSession(startedAt: startedAt)
        let exercise = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        context.insert(session)
        context.insert(exercise)
        context.insert(SetEntry(exerciseEntry: entry, order: 0, weightKg: 40, reps: 10))
        context.insert(SetEntry(exerciseEntry: entry, order: 1, weightKg: 40, reps: 8))
        try context.save()

        let summary = try WorkoutSessionService(context: context, now: { endedAt }).finish(session)

        XCTAssertEqual(session.endedAt, endedAt)
        XCTAssertEqual(summary.duration, 3_900)
        XCTAssertEqual(summary.exerciseCount, 1)
        XCTAssertEqual(summary.setCount, 2)
        XCTAssertFalse(context.hasChanges)
        XCTAssertNil(try WorkoutSessionService(context: context).activeSession())
    }

    /// テスト概要: セットがないセッションをサービスから終了しようとする。
    /// 期待値: 終了は拒否され、進行中セッションのまま保存データが維持される。
    func testFinishingWorkoutWithoutSetsIsRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        context.insert(session)
        try context.save()

        XCTAssertThrowsError(try WorkoutSessionService(context: context).finish(session)) { error in
            XCTAssertEqual(error as? WorkoutSessionError, .noSavedSets)
        }
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).count, 1)
    }

    /// テスト概要: 空の種目を含むセッションを終了する。
    /// 期待値: 空の種目は削除され、保存済みセットを持つ種目だけが連番で残る。
    func testFinishingWorkoutRemovesEmptyExercisesAndRenumbersRemainingEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercises = (0..<3).map { Exercise(name: "種目\($0)", primaryBodyPart: .other) }
        let entries = exercises.enumerated().map {
            ExerciseEntry(workoutSession: session, exercise: $0.element, order: $0.offset)
        }
        context.insert(session)
        exercises.forEach(context.insert)
        context.insert(SetEntry(exerciseEntry: entries[0], order: 0, weightKg: 10, reps: 10))
        context.insert(SetEntry(exerciseEntry: entries[2], order: 0, weightKg: 20, reps: 5))
        try context.save()

        let summary = try WorkoutSessionService(context: context).finish(session)

        let remaining = try context.fetch(FetchDescriptor<ExerciseEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(remaining.map(\.exerciseNameSnapshot), ["種目0", "種目2"])
        XCTAssertEqual(remaining.map(\.order), [0, 1])
        XCTAssertEqual(summary.exerciseCount, 2)
        XCTAssertEqual(summary.setCount, 2)
    }

    /// テスト概要: 保存済みセットに続く有効な未追加Draftを伴ってセッションを終了する。
    /// 期待値: Draftが同じ種目の次のorderで保存され、終了日時と集計も同時に確定する。
    func testFinishingWorkoutSavesValidDraftWithNextOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let endedAt = Date(timeIntervalSince1970: 9_000)
        let session = WorkoutSession()
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        context.insert(entry)
        context.insert(SetEntry(exerciseEntry: entry, order: 0, weightKg: 80, reps: 5))
        try context.save()

        let summary = try WorkoutSessionService(context: context, now: { endedAt }).finish(
            session,
            drafts: [entry.id: SetEntryDraft(weight: "82.5", reps: "4")]
        )

        let sets = entry.setEntries.sorted { $0.order < $1.order }
        XCTAssertEqual(sets.map(\.order), [0, 1])
        XCTAssertEqual(sets.last?.exerciseEntry?.id, entry.id)
        XCTAssertEqual(sets.last?.weightKg, 82.5)
        XCTAssertEqual(sets.last?.reps, 4)
        XCTAssertEqual(summary.setCount, 2)
        XCTAssertEqual(session.endedAt, endedAt)
    }

    /// テスト概要: 複数種目の有効な未追加Draftを伴ってセッションを終了する。
    /// 期待値: 各Draftが対応する親種目へorder 0で1件ずつ保存される。
    func testFinishingWorkoutSavesDraftsForTheirExerciseEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let entries = [
            ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
                order: 0
            ),
            ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: "デッドリフト", primaryBodyPart: .back),
                order: 1
            ),
        ]
        entries.forEach(context.insert)
        try context.save()

        let summary = try WorkoutSessionService(context: context).finish(
            session,
            drafts: [
                entries[0].id: SetEntryDraft(weight: "40", reps: "10"),
                entries[1].id: SetEntryDraft(weight: "100", reps: "5"),
            ]
        )

        XCTAssertEqual(summary.exerciseCount, 2)
        XCTAssertEqual(summary.setCount, 2)
        XCTAssertEqual(entries[0].setEntries.map(\.order), [0])
        XCTAssertEqual(entries[0].setEntries.first?.weightKg, 40)
        XCTAssertEqual(entries[1].setEntries.map(\.order), [0])
        XCTAssertEqual(entries[1].setEntries.first?.weightKg, 100)
    }

    /// テスト概要: 空Draftと、片方のみ入力またはvalidation不正なDraftで終了を試みる。
    /// 期待値: 空Draftは保存対象にならず、不正な各Draftは終了を拒否して入力値自体を変更しない。
    func testFinishingWorkoutIgnoresEmptyDraftAndRejectsInvalidDrafts() throws {
        let invalidDrafts = [
            SetEntryDraft(weight: "10", reps: ""),
            SetEntryDraft(weight: "", reps: "8"),
            SetEntryDraft(weight: "10", reps: "0"),
            SetEntryDraft(weight: "abc", reps: "8"),
        ]

        for invalidDraft in invalidDrafts {
            let container = try makeContainer()
            let context = container.mainContext
            let session = WorkoutSession()
            let savedEntry = ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: "保存済み", primaryBodyPart: .other),
                order: 0
            )
            let emptyEntry = ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: "空", primaryBodyPart: .other),
                order: 1
            )
            context.insert(savedEntry)
            context.insert(emptyEntry)
            context.insert(SetEntry(exerciseEntry: savedEntry, order: 0, weightKg: 10, reps: 1))
            try context.save()

            XCTAssertThrowsError(
                try WorkoutSessionService(context: context).finish(
                    session,
                    drafts: [
                        savedEntry.id: invalidDraft,
                        emptyEntry.id: SetEntryDraft(),
                    ]
                )
            ) { error in
                XCTAssertEqual(error as? WorkoutSetError, .invalidValues)
            }
            XCTAssertNil(session.endedAt)
            XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
        }
    }

    /// テスト概要: 保存済みセットがあるWorkoutを別種目の空Draftとともに終了する。
    /// 期待値: 空DraftからSetEntryは作られず、Workoutの終了は妨げられない。
    func testFinishingWorkoutDoesNotSaveEmptyDraft() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let savedEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "保存済み", primaryBodyPart: .other),
            order: 0
        )
        let emptyEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "未入力", primaryBodyPart: .other),
            order: 1
        )
        context.insert(savedEntry)
        context.insert(emptyEntry)
        context.insert(SetEntry(exerciseEntry: savedEntry, order: 0, weightKg: 10, reps: 10))
        try context.save()

        let summary = try WorkoutSessionService(context: context).finish(
            session,
            drafts: [emptyEntry.id: SetEntryDraft()]
        )

        XCTAssertEqual(summary.exerciseCount, 1)
        XCTAssertEqual(summary.setCount, 1)
        XCTAssertNotNil(session.endedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
    }

    /// テスト概要: 先の種目が有効、後の種目が不正なDraftを持つ状態で終了する。
    /// 期待値: 途中まで生成したSetEntryもrollbackされ、部分的な自動保存が残らない。
    func testFinishingWorkoutInvalidLaterDraftRollsBackEarlierDraft() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let entries = [
            ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: "先", primaryBodyPart: .other),
                order: 0
            ),
            ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: "後", primaryBodyPart: .other),
                order: 1
            ),
        ]
        entries.forEach(context.insert)
        try context.save()

        XCTAssertThrowsError(
            try WorkoutSessionService(context: context).finish(
                session,
                drafts: [
                    entries[0].id: SetEntryDraft(weight: "20", reps: "10"),
                    entries[1].id: SetEntryDraft(weight: "20", reps: "0"),
                ]
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutSetError, .invalidValues)
        }

        XCTAssertNil(session.endedAt)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
    }

    /// テスト概要: Draft追加とWorkout終了を確定するsaveが失敗する。
    /// 期待値: endedAtとSetEntryの追加がともにrollbackされ、呼び出し元のDraft入力は維持される。
    func testFinishingWorkoutSaveFailureKeepsWorkoutAndDraftUnchanged() throws {
        struct ExpectedError: Error {}

        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "プレス", primaryBodyPart: .shoulders),
            order: 0
        )
        context.insert(entry)
        try context.save()
        let draft = SetEntryDraft(weight: "30", reps: "8")
        let service = WorkoutSessionService(context: context, save: { throw ExpectedError() })

        XCTAssertThrowsError(try service.finish(session, drafts: [entry.id: draft]))

        XCTAssertNil(session.endedAt)
        XCTAssertEqual(draft, SetEntryDraft(weight: "30", reps: "8"))
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
    }

    /// テスト概要: 同じDraftを渡して終了操作を繰り返す。
    /// 期待値: 2回目は終了済みとして拒否され、同じSetEntryが二重保存されない。
    func testRepeatingFinishDoesNotSaveDraftTwice() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "カール", primaryBodyPart: .arms),
            order: 0
        )
        context.insert(entry)
        try context.save()
        let drafts = [entry.id: SetEntryDraft(weight: "10", reps: "12")]
        let service = WorkoutSessionService(context: context)

        _ = try service.finish(session, drafts: drafts)
        XCTAssertThrowsError(try service.finish(session, drafts: drafts)) { error in
            XCTAssertEqual(error as? WorkoutSessionError, .alreadyFinished)
        }

        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
    }

    /// テスト概要: 保存済みセットに対する編集Draftの変更有無を判定する。
    /// 期待値: 保存値と同じDraftは未変更、重量または回数を編集したDraftは変更ありと判定される。
    func testSetEditDraftDetectsUnsavedChanges() {
        let exercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let entry = ExerciseEntry(workoutSession: WorkoutSession(), exercise: exercise, order: 0)
        let setEntry = SetEntry(exerciseEntry: entry, order: 0, weightKg: 40, reps: 10)

        XCTAssertFalse(SetEntryDraft(weight: "40", reps: "10").hasChanges(from: setEntry))
        XCTAssertTrue(SetEntryDraft(weight: "42.5", reps: "10").hasChanges(from: setEntry))
        XCTAssertTrue(SetEntryDraft(weight: "40", reps: "8").hasChanges(from: setEntry))
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

    /// テスト概要: 有効なDraftをセットとして追加する。
    /// 期待値: 小数重量と回数が末尾order、非ウォームアップとして明示的に保存される。
    func testAddingSetFromValidDraftSavesCompletedEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exerciseEntry = ExerciseEntry(
            workoutSession: WorkoutSession(),
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 0
        )
        context.insert(exerciseEntry)
        try context.save()

        let setEntry = try WorkoutSetService(context: context).add(
            draft: SetEntryDraft(weight: "7.50", reps: "12"),
            to: exerciseEntry
        )

        XCTAssertEqual(setEntry.weightKg, 7.5)
        XCTAssertEqual(setEntry.reps, 12)
        XCTAssertEqual(setEntry.order, 0)
        XCTAssertFalse(setEntry.isWarmup)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 未確定Draftおよび不正な値を検証する。
    /// 期待値: 空欄、負数、3桁小数、0回、小数回は拒否され、0kgは許可される。
    func testSetDraftValidationRejectsIncompleteAndInvalidValues() {
        XCTAssertTrue(SetEntryDraft().isEmpty)
        XCTAssertFalse(SetEntryDraft(weight: "10", reps: "").isEmpty)
        XCTAssertFalse(SetEntryDraft(weight: "", reps: "8").isEmpty)
        XCTAssertNil(SetEntryDraft().values(decimalSeparator: "."))
        XCTAssertNil(SetEntryDraft(weight: "-1", reps: "1").values(decimalSeparator: "."))
        XCTAssertNil(SetEntryDraft(weight: "1.234", reps: "1").values(decimalSeparator: "."))
        XCTAssertNil(SetEntryDraft(weight: "10", reps: "0").values(decimalSeparator: "."))
        XCTAssertNil(SetEntryDraft(weight: "10", reps: "1.5").values(decimalSeparator: "."))
        XCTAssertEqual(SetEntryDraft(weight: "0", reps: "1").values(decimalSeparator: ".")?.weight, 0)
        XCTAssertEqual(SetEntryDraft(weight: "7,5", reps: "8").values(decimalSeparator: ",")?.weight, 7.5)
    }

    /// テスト概要: 保存済みセットを編集用Draftへ変換する。
    /// 期待値: 桁区切りやローカライズされた数字を含まず、指定された小数点で検証可能な文字列になる。
    func testSavedSetDraftUsesValidatorCompatibleWeightText() {
        let exerciseEntry = ExerciseEntry(
            workoutSession: WorkoutSession(),
            exercise: Exercise(name: "デッドリフト", primaryBodyPart: .back),
            order: 0
        )
        let setEntry = SetEntry(
            exerciseEntry: exerciseEntry,
            order: 0,
            weightKg: 1_000.5,
            reps: 8
        )

        let draft = SetEntryDraft.savedValues(from: setEntry, decimalSeparator: ",")

        XCTAssertEqual(draft, SetEntryDraft(weight: "1000,5", reps: "8"))
        XCTAssertEqual(draft.values(decimalSeparator: ",")?.weight, 1_000.5)
    }

    /// テスト概要: 保存済みセットを修正する。
    /// 期待値: 重量と回数だけが更新され、orderとウォームアップ状態は維持される。
    func testUpdatingSetPreservesOrderingAndWarmupState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exerciseEntry = ExerciseEntry(
            workoutSession: WorkoutSession(),
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let setEntry = SetEntry(
            exerciseEntry: exerciseEntry,
            order: 2,
            weightKg: 80,
            reps: 5,
            isWarmup: true
        )
        context.insert(setEntry)
        try context.save()

        try WorkoutSetService(context: context).update(
            setEntry,
            draft: SetEntryDraft(weight: "82.5", reps: "6")
        )

        XCTAssertEqual(setEntry.weightKg, 82.5)
        XCTAssertEqual(setEntry.reps, 6)
        XCTAssertEqual(setEntry.order, 2)
        XCTAssertTrue(setEntry.isWarmup)
    }

    /// テスト概要: 中間のセットを削除する。
    /// 期待値: 同じ種目の残存セットだけが0始まりの連番になり、別種目のセットは変化しない。
    func testDeletingSetRenumbersOnlyItsExerciseEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "デッドリフト", primaryBodyPart: .back)
        let firstEntry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        let secondEntry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 1)
        let firstSets = (0..<3).map {
            SetEntry(exerciseEntry: firstEntry, order: $0, weightKg: Double($0), reps: 1)
        }
        let otherSet = SetEntry(exerciseEntry: secondEntry, order: 4, weightKg: 10, reps: 2)
        firstSets.forEach(context.insert)
        context.insert(otherSet)
        try context.save()

        try WorkoutSetService(context: context).delete(firstSets[1], from: firstEntry)

        XCTAssertEqual(firstEntry.setEntries.sorted { $0.order < $1.order }.map(\.order), [0, 1])
        XCTAssertEqual(secondEntry.setEntries.map(\.order), [4])
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 3)
    }
}

import Observation
import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class KASANETests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func makeDashboardSession(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 10,
        duration: TimeInterval,
        calendar: Calendar,
        weight: Double = 0,
        reps: Int = 0,
        exercise: Exercise? = nil,
        weights: [Double]? = nil
    ) throws -> WorkoutSession {
        let start = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: year, month: month, day: day, hour: hour)
            ))
        let session = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(duration))
        let exercise = exercise ?? Exercise(name: "テスト種目", primaryBodyPart: .other)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        session.exerciseEntries.append(entry)
        for (order, value) in (weights ?? [weight]).enumerated() {
            let set = SetEntry(exerciseEntry: entry, order: order, weightKg: value, reps: reps)
            entry.setEntries.append(set)
        }
        return session
    }

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

    private func makePersonalRecordWorkout(
        exercise: Exercise,
        startedAt: TimeInterval,
        endedAt: TimeInterval?,
        weights: [Double]
    ) -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: startedAt),
            endedAt: endedAt.map(Date.init(timeIntervalSince1970:))
        )
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        session.exerciseEntries.append(entry)
        for (order, weight) in weights.enumerated() {
            entry.setEntries.append(
                SetEntry(exerciseEntry: entry, order: order, weightKg: weight, reps: 10)
            )
        }
        return session
    }

    private func makeExerciseOverviewSession(
        exercise: Exercise,
        completedAt: TimeInterval,
        weights: [Double],
        reps: Int = 10,
        isCompleted: Bool = true
    ) -> WorkoutSession {
        let endedAt = Date(timeIntervalSince1970: completedAt)
        let session = WorkoutSession(
            startedAt: endedAt.addingTimeInterval(-600),
            endedAt: isCompleted ? endedAt : nil
        )
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        session.exerciseEntries.append(entry)
        entry.setEntries = weights.enumerated().map {
            SetEntry(exerciseEntry: entry, order: $0.offset, weightKg: $0.element, reps: reps)
        }
        return session
    }

    private func makeExerciseProgressSession(
        exercise: Exercise,
        completedAt: TimeInterval,
        sets: [(weight: Double, reps: Int)],
        isCompleted: Bool = true
    ) -> WorkoutSession {
        let end = Date(timeIntervalSince1970: completedAt)
        let session = WorkoutSession(
            startedAt: end.addingTimeInterval(-600),
            endedAt: isCompleted ? end : nil
        )
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        session.exerciseEntries.append(entry)
        entry.setEntries = sets.enumerated().map {
            SetEntry(
                exerciseEntry: entry,
                order: $0.offset,
                weightKg: $0.element.weight,
                reps: $0.element.reps
            )
        }
        return session
    }

    func testWorkoutInsightFactsBuildsSavedMetricsRecordsAndPreviousComparison() throws {
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let previous = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let previousEntry = ExerciseEntry(
            workoutSession: previous,
            exercise: exercise,
            order: 0
        )
        previous.exerciseEntries.append(previousEntry)
        previousEntry.setEntries = [
            SetEntry(exerciseEntry: previousEntry, order: 0, weightKg: 30, reps: 10),
            SetEntry(exerciseEntry: previousEntry, order: 1, weightKg: 20, reps: 5),
        ]

        let current = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 300),
            endedAt: Date(timeIntervalSince1970: 3_900)
        )
        let currentEntry = ExerciseEntry(
            workoutSession: current,
            exercise: exercise,
            order: 0
        )
        current.exerciseEntries.append(currentEntry)
        currentEntry.setEntries = [
            SetEntry(exerciseEntry: currentEntry, order: 0, weightKg: 32.5, reps: 10),
            SetEntry(exerciseEntry: currentEntry, order: 1, weightKg: 25, reps: 8),
        ]
        let summary = WorkoutCompletionSummary(
            startedAt: current.startedAt,
            endedAt: try XCTUnwrap(current.endedAt),
            exerciseCount: 1,
            setCount: 2
        )
        let record = PersonalRecordAchievement(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            previousBest: 30,
            newBest: 32.5
        )

        let facts = WorkoutInsightFactsBuilder.build(
            summary: summary,
            session: current,
            personalRecords: [record],
            sessions: [previous, current]
        )

        XCTAssertEqual(facts.duration, 3_600)
        XCTAssertEqual(facts.exerciseCount, 1)
        XCTAssertEqual(facts.setCount, 2)
        XCTAssertEqual(facts.totalVolume, 525)
        XCTAssertEqual(
            facts.personalRecords,
            [.init(exerciseName: "チェストプレス", previousBest: 30, newBest: 32.5, improvement: 2.5)]
        )
        let comparison = try XCTUnwrap(facts.exerciseComparisons.first)
        XCTAssertEqual(comparison.currentMaxWeight, 32.5)
        XCTAssertEqual(comparison.previousMaxWeight, 30)
        XCTAssertEqual(comparison.maxWeightDifference, 2.5)
        XCTAssertEqual(comparison.currentVolume, 525)
        XCTAssertEqual(comparison.previousVolume, 400)
        XCTAssertEqual(comparison.volumeDifference, 125)
    }

    func testWorkoutInsightFactsOmitsExerciseWithoutPreviousWorkout() {
        let exercise = Exercise(name: "初回種目", primaryBodyPart: .other)
        let current = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 300,
            endedAt: 400,
            weights: [40]
        )
        let summary = WorkoutCompletionSummary(
            startedAt: current.startedAt,
            endedAt: current.endedAt ?? current.startedAt,
            exerciseCount: 1,
            setCount: 1
        )

        let facts = WorkoutInsightFactsBuilder.build(
            summary: summary,
            session: current,
            personalRecords: [],
            sessions: [current]
        )

        XCTAssertTrue(facts.exerciseComparisons.isEmpty)
        XCTAssertFalse(facts.isEligibleForGeneration)
    }

    func testWorkoutInsightVolumeClampsInvalidValues() {
        let exercise = Exercise(name: "テスト", primaryBodyPart: .other)
        let session = WorkoutSession(startedAt: .now)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        let sets = [
            SetEntry(exerciseEntry: entry, order: 0, weightKg: -10, reps: 5),
            SetEntry(exerciseEntry: entry, order: 1, weightKg: 20, reps: -3),
            SetEntry(exerciseEntry: entry, order: 2, weightKg: 12.5, reps: 8),
        ]

        XCTAssertEqual(WorkoutInsightFactsBuilder.volume(of: sets), 100)
    }

    func testWorkoutInsightEligibilityRequiresRecordOrPositiveDifference() {
        let base = WorkoutInsightExerciseComparisonFact(
            exerciseName: "テスト",
            currentMaxWeight: 20,
            previousMaxWeight: 20,
            maxWeightDifference: 0,
            currentVolume: 200,
            previousVolume: 200,
            volumeDifference: 0
        )
        let noImprovement = WorkoutInsightFacts(
            duration: 60,
            exerciseCount: 1,
            setCount: 1,
            totalVolume: 200,
            personalRecords: [],
            exerciseComparisons: [base]
        )
        XCTAssertFalse(noImprovement.isEligibleForGeneration)

        let record = WorkoutInsightPersonalRecordFact(
            exerciseName: "テスト",
            previousBest: 10,
            newBest: 20,
            improvement: 10
        )
        XCTAssertTrue(
            WorkoutInsightFacts(
                duration: 60, exerciseCount: 1, setCount: 1, totalVolume: 200,
                personalRecords: [record], exerciseComparisons: []
            ).isEligibleForGeneration
        )
        XCTAssertTrue(
            noImprovementReplacing(base, maxWeightDifference: 1).isEligibleForGeneration
        )
        XCTAssertTrue(noImprovementReplacing(base, volumeDifference: 1).isEligibleForGeneration)
    }

    func testWorkoutInsightViewModelShowsOnlySuccessfulGeneration() async {
        let viewModel = WorkoutInsightViewModel()
        await viewModel.generate(facts: eligibleInsightFacts, using: FixtureWorkoutInsightGenerator())
        XCTAssertEqual(viewModel.insight?.headline, "記録を更新")

        let failedViewModel = WorkoutInsightViewModel()
        await failedViewModel.generate(facts: eligibleInsightFacts, using: FailingInsightGenerator())
        XCTAssertEqual(failedViewModel.state, .failed)
        XCTAssertNil(failedViewModel.insight)

        let unavailableViewModel = WorkoutInsightViewModel()
        await unavailableViewModel.generate(
            facts: eligibleInsightFacts,
            using: UnavailableInsightGenerator()
        )
        XCTAssertEqual(unavailableViewModel.state, .failed)
        XCTAssertNil(unavailableViewModel.insight)
    }

    func testWorkoutInsightViewModelDoesNotGenerateWhenIneligible() async {
        let generator = CountingInsightGenerator()
        let viewModel = WorkoutInsightViewModel()
        await viewModel.generate(
            facts: WorkoutInsightFacts(
                duration: 60,
                exerciseCount: 1,
                setCount: 1,
                totalVolume: 100,
                personalRecords: [],
                exerciseComparisons: []
            ),
            using: generator
        )
        XCTAssertEqual(generator.callCount, 0)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testWorkoutInsightCancellationDoesNotPublishFailureOrResult() async {
        let viewModel = WorkoutInsightViewModel()
        let task = Task {
            await viewModel.generate(
                facts: eligibleInsightFacts,
                using: DelayedInsightGenerator()
            )
        }
        task.cancel()
        await task.value

        XCTAssertNil(viewModel.insight)
        XCTAssertNotEqual(viewModel.state, .failed)
    }

    private var eligibleInsightFacts: WorkoutInsightFacts {
        WorkoutInsightFacts(
            duration: 60,
            exerciseCount: 1,
            setCount: 1,
            totalVolume: 200,
            personalRecords: [
                .init(exerciseName: "テスト", previousBest: 10, newBest: 20, improvement: 10)
            ],
            exerciseComparisons: []
        )
    }

    private func noImprovementReplacing(
        _ comparison: WorkoutInsightExerciseComparisonFact,
        maxWeightDifference: Double = 0,
        volumeDifference: Double = 0
    ) -> WorkoutInsightFacts {
        WorkoutInsightFacts(
            duration: 60,
            exerciseCount: 1,
            setCount: 1,
            totalVolume: 200,
            personalRecords: [],
            exerciseComparisons: [
                .init(
                    exerciseName: comparison.exerciseName,
                    currentMaxWeight: comparison.currentMaxWeight,
                    previousMaxWeight: comparison.previousMaxWeight,
                    maxWeightDifference: maxWeightDifference,
                    currentVolume: comparison.currentVolume,
                    previousVolume: comparison.previousVolume,
                    volumeDifference: volumeDifference
                )
            ]
        )
    }

    /// 過去最高63kgに対して今回の複数セット中の最高72kgを1件のPRとして検出する。
    func testPersonalRecordDetectorUsesCurrentWorkoutMaximum() throws {
        let exercise = Exercise(name: "レッグプレス", primaryBodyPart: .legs)
        let previous = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 100,
            endedAt: 200,
            weights: [63]
        )
        let current = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 300,
            endedAt: 400,
            weights: [63, 72, 68]
        )

        let achievement = try XCTUnwrap(
            PersonalRecordDetector.achievements(for: current, among: [previous, current]).first
        )
        XCTAssertEqual(achievement.exerciseID, exercise.id)
        XCTAssertEqual(achievement.previousBest, 63)
        XCTAssertEqual(achievement.newBest, 72)
        XCTAssertEqual(achievement.improvement, 9)
    }

    /// 同値または過去最高を下回る今回値はPRにしない。
    func testPersonalRecordDetectorRejectsEqualAndLowerWeights() {
        let exercise = Exercise(name: "レッグプレス", primaryBodyPart: .legs)
        let previous = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 100,
            endedAt: 200,
            weights: [72]
        )
        for weight in [72.0, 63.0] {
            let current = makePersonalRecordWorkout(
                exercise: exercise,
                startedAt: 300,
                endedAt: 400,
                weights: [weight]
            )
            XCTAssertTrue(
                PersonalRecordDetector.achievements(for: current, among: [previous]).isEmpty
            )
        }
    }

    /// 複数の過去Workoutから最大値を採用し、未完了・未来・今回自身は除外する。
    func testPersonalRecordDetectorUsesEligibleHistoricalMaximumOnly() throws {
        let exercise = Exercise(name: "レッグプレス", primaryBodyPart: .legs)
        let historical = [54.0, 63.0, 60.0].enumerated().map { index, weight in
            makePersonalRecordWorkout(
                exercise: exercise,
                startedAt: TimeInterval(100 + index * 20),
                endedAt: TimeInterval(110 + index * 20),
                weights: [weight]
            )
        }
        let incomplete = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 250,
            endedAt: nil,
            weights: [100]
        )
        let current = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 300,
            endedAt: 400,
            weights: [72]
        )
        let future = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 500,
            endedAt: 600,
            weights: [110]
        )

        let achievement = try XCTUnwrap(
            PersonalRecordDetector.achievements(
                for: current,
                among: historical + [incomplete, current, future]
            ).first
        )
        XCTAssertEqual(achievement.previousBest, 63)
        XCTAssertEqual(achievement.newBest, 72)
    }

    /// 初回記録は比較対象がないためPR演出の対象にしない。
    func testPersonalRecordDetectorDoesNotTreatFirstRecordAsAchievement() {
        let exercise = Exercise(name: "レッグプレス", primaryBodyPart: .legs)
        let current = makePersonalRecordWorkout(
            exercise: exercise,
            startedAt: 300,
            endedAt: 400,
            weights: [72]
        )

        XCTAssertTrue(PersonalRecordDetector.achievements(for: current, among: []).isEmpty)
    }

    /// Exercise IDごとに独立して比較し、複数種目のPRを順序どおり返す。
    func testPersonalRecordDetectorReturnsMultipleExercises() {
        let legPress = Exercise(name: "レッグプレス", primaryBodyPart: .legs)
        let chestPress = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let previous = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let current = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 300),
            endedAt: Date(timeIntervalSince1970: 400)
        )
        for (order, fixture) in [(legPress, 63.0, 72.0), (chestPress, 40.0, 45.0)].enumerated() {
            let oldEntry = ExerciseEntry(
                workoutSession: previous,
                exercise: fixture.0,
                order: order
            )
            oldEntry.setEntries.append(
                SetEntry(exerciseEntry: oldEntry, order: 0, weightKg: fixture.1, reps: 10)
            )
            previous.exerciseEntries.append(oldEntry)
            let newEntry = ExerciseEntry(
                workoutSession: current,
                exercise: fixture.0,
                order: order
            )
            newEntry.setEntries.append(
                SetEntry(exerciseEntry: newEntry, order: 0, weightKg: fixture.2, reps: 10)
            )
            current.exerciseEntries.append(newEntry)
        }

        let achievements = PersonalRecordDetector.achievements(for: current, among: [previous])

        XCTAssertEqual(achievements.map(\.exerciseID), [legPress.id, chestPress.id])
        XCTAssertEqual(achievements.map(\.improvement), [9, 5])
    }

    /// テスト概要: アプリ内の公開リンク定義を取得する。
    /// 期待値: SupportとPrivacy PolicyがIssueで確定したHTTPS URLに一致する。
    func testAppLinksUsePublishedURLs() {
        XCTAssertEqual(
            AppLinks.support?.absoluteString,
            "https://yu1ro5.github.io/kasane/support/"
        )
        XCTAssertEqual(
            AppLinks.privacyPolicy?.absoluteString,
            "https://yu1ro5.github.io/kasane/privacy/"
        )
    }

    /// テスト概要: CFBundleShortVersionStringが存在しないBundle情報を読み取る。
    /// 期待値: クラッシュせず、表示可能な代替文字列を返す。
    func testAppVersionSafelyHandlesMissingValue() {
        XCTAssertEqual(AppVersion.shortVersion(from: nil), "—")
        XCTAssertEqual(AppVersion.shortVersion(from: [:]), "—")
    }

    /// テスト概要: CFBundleShortVersionStringをBundle情報から読み取る。
    /// 期待値: ビルド設定から展開された値をそのまま返す。
    func testAppVersionReadsShortVersion() {
        XCTAssertEqual(
            AppVersion.shortVersion(from: ["CFBundleShortVersionString": "1.2.3"]),
            "1.2.3"
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

    /// テスト概要: 複数Workout・複数種目の未確定Draftを更新する。
    /// 期待値: DraftはSessionとExerciseEntryごとに分離され、入力文字列をそのまま保持する。
    func testWorkoutDraftStoreKeepsDraftsScopedToSessionAndExercise() {
        let store = WorkoutDraftStore()
        let firstSessionID = UUID()
        let secondSessionID = UUID()
        let firstEntryID = UUID()
        let secondEntryID = UUID()

        store.update(
            SetEntryDraft(weight: "60", reps: ""),
            for: firstEntryID,
            in: firstSessionID
        )
        store.update(
            SetEntryDraft(weight: "", reps: "12"),
            for: secondEntryID,
            in: firstSessionID
        )
        store.update(
            SetEntryDraft(weight: "100", reps: "5"),
            for: firstEntryID,
            in: secondSessionID
        )

        XCTAssertEqual(
            store.draft(for: firstEntryID, in: firstSessionID),
            SetEntryDraft(weight: "60", reps: "")
        )
        XCTAssertEqual(
            store.draft(for: secondEntryID, in: firstSessionID),
            SetEntryDraft(weight: "", reps: "12")
        )
        XCTAssertEqual(
            store.draft(for: firstEntryID, in: secondSessionID),
            SetEntryDraft(weight: "100", reps: "5")
        )
    }

    /// テスト概要: ExerciseEntry生成前の入力を一覧へ戻った後に取得する。
    /// 期待値: DraftはSessionとExerciseごとに分離され、同じ種目を開き直すと復元される。
    func testWorkoutDraftStoreKeepsPendingDraftsScopedToSessionAndExercise() {
        let store = WorkoutDraftStore()
        let firstSessionID = UUID()
        let secondSessionID = UUID()
        let exerciseID = UUID()

        store.updatePending(
            SetEntryDraft(weight: "14", reps: ""),
            for: exerciseID,
            in: firstSessionID
        )
        store.updatePending(
            SetEntryDraft(weight: "20", reps: "8"),
            for: exerciseID,
            in: secondSessionID
        )

        XCTAssertEqual(
            store.pendingDraft(for: exerciseID, in: firstSessionID),
            SetEntryDraft(weight: "14", reps: "")
        )
        XCTAssertEqual(
            store.pendingDraft(for: exerciseID, in: secondSessionID),
            SetEntryDraft(weight: "20", reps: "8")
        )
    }

    /// テスト概要: 空になったDraftと終了したWorkoutのDraftを消去する。
    /// 期待値: 空Draftは保持されず、Session単位で残りのDraftも消去できる。
    func testWorkoutDraftStoreRemovesEmptyAndCompletedSessionDrafts() {
        let store = WorkoutDraftStore()
        let sessionID = UUID()
        let firstEntryID = UUID()
        let secondEntryID = UUID()
        let exerciseID = UUID()
        store.update(SetEntryDraft(weight: "20", reps: "5"), for: firstEntryID, in: sessionID)
        store.update(SetEntryDraft(weight: "40", reps: "8"), for: secondEntryID, in: sessionID)
        store.updatePending(
            SetEntryDraft(weight: "14", reps: ""),
            for: exerciseID,
            in: sessionID
        )

        store.update(SetEntryDraft(), for: firstEntryID, in: sessionID)
        store.updatePending(SetEntryDraft(), for: exerciseID, in: sessionID)

        XCTAssertEqual(store.draft(for: firstEntryID, in: sessionID), SetEntryDraft())
        XCTAssertEqual(store.drafts(for: sessionID).count, 1)
        XCTAssertEqual(store.pendingDraft(for: exerciseID, in: sessionID), SetEntryDraft())

        store.updatePending(
            SetEntryDraft(weight: "14", reps: ""),
            for: exerciseID,
            in: sessionID
        )

        store.removeAllDrafts(in: sessionID)

        XCTAssertTrue(store.drafts(for: sessionID).isEmpty)
        XCTAssertTrue(store.pendingDrafts(for: sessionID).isEmpty)
    }

    /// テスト概要: Set確定前に未記録だった種目のDraftを削除する。
    /// 期待値: pending Draftだけが削除され、新規Entry側にDraftは作られない。
    func testWorkoutDraftStoreRemovesPendingDraftAfterFirstSetCommit() {
        let store = WorkoutDraftStore()
        let sessionID = UUID()
        let exerciseID = UUID()
        let createdEntryID = UUID()
        store.updatePending(
            SetEntryDraft(weight: "5", reps: "5"),
            for: exerciseID,
            in: sessionID
        )

        store.removeCommittedDraft(
            for: exerciseID,
            entryIDBeforeCommit: nil,
            in: sessionID
        )

        XCTAssertTrue(store.pendingDrafts(for: sessionID).isEmpty)
        XCTAssertEqual(store.draft(for: createdEntryID, in: sessionID), SetEntryDraft())
        XCTAssertTrue(store.drafts(for: sessionID).isEmpty)
    }

    /// テスト概要: Set確定前から記録済みだった種目のDraftを削除する。
    /// 期待値: Entry側のDraftだけが削除され、pending Draftには影響しない。
    func testWorkoutDraftStoreRemovesExistingEntryDraftAfterSetCommit() {
        let store = WorkoutDraftStore()
        let sessionID = UUID()
        let exerciseID = UUID()
        let entryID = UUID()
        let unrelatedPendingExerciseID = UUID()
        store.update(SetEntryDraft(weight: "10", reps: "8"), for: entryID, in: sessionID)
        store.updatePending(
            SetEntryDraft(weight: "20", reps: "10"),
            for: unrelatedPendingExerciseID,
            in: sessionID
        )

        store.removeCommittedDraft(
            for: exerciseID,
            entryIDBeforeCommit: entryID,
            in: sessionID
        )

        XCTAssertTrue(store.drafts(for: sessionID).isEmpty)
        XCTAssertEqual(
            store.pendingDraft(for: unrelatedPendingExerciseID, in: sessionID),
            SetEntryDraft(weight: "20", reps: "10")
        )
    }

    /// テスト概要: 新しいアプリ起動に相当するStoreを生成する。
    /// 期待値: 以前の起動中に入力したDraftは復元されない。
    func testWorkoutDraftStoreDoesNotRestoreDraftAfterStoreRecreation() {
        let sessionID = UUID()
        let entryID = UUID()
        let store = WorkoutDraftStore()
        store.update(SetEntryDraft(weight: "12.", reps: ""), for: entryID, in: sessionID)

        let recreatedStore = WorkoutDraftStore()

        XCTAssertEqual(recreatedStore.draft(for: entryID, in: sessionID), SetEntryDraft())
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

    /// テスト概要: 完了Workoutを履歴削除し、共有Exerciseを参照する別Workoutを取得する。
    /// 期待値: 対象と配下だけがcascade削除され、別WorkoutとExerciseマスタは残る。
    func testDeletingCompletedWorkoutCascadesOnlyThroughItsOwnedGraph() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workoutSession = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let otherWorkoutSession = WorkoutSession(endedAt: Date(timeIntervalSince1970: 3_000))
        let exercise = Exercise(name: "Deadlift", primaryBodyPart: .back)
        let exerciseEntry = ExerciseEntry(workoutSession: workoutSession, exercise: exercise, order: 0)
        let otherExerciseEntry = ExerciseEntry(
            workoutSession: otherWorkoutSession,
            exercise: exercise,
            order: 0
        )
        workoutSession.exerciseEntries.append(exerciseEntry)
        exerciseEntry.setEntries.append(
            SetEntry(exerciseEntry: exerciseEntry, order: 0, weightKg: 120, reps: 5)
        )
        otherWorkoutSession.exerciseEntries.append(otherExerciseEntry)
        otherExerciseEntry.setEntries.append(
            SetEntry(exerciseEntry: otherExerciseEntry, order: 0, weightKg: 125, reps: 3)
        )
        context.insert(workoutSession)
        context.insert(otherWorkoutSession)
        context.insert(exercise)
        try context.save()

        try WorkoutSessionService(context: context).deleteCompleted(workoutSession)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.map(\.id), [otherWorkoutSession.id])
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<ExerciseEntry>()).map(\.id),
            [
                otherExerciseEntry.id
            ])
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 進行中Workoutに履歴削除を要求する。
    /// 期待値: 専用エラーで拒否され、Workoutは永続ストアに残る。
    func testDeletingActiveWorkoutAsCompletedIsRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        context.insert(session)
        try context.save()

        XCTAssertThrowsError(
            try WorkoutSessionService(context: context).deleteCompleted(session)
        ) { error in
            XCTAssertEqual(error as? WorkoutSessionError, .notCompleted)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).map(\.id), [session.id])
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

    /// テスト概要: Rootから新しいWorkoutの開始に成功する。
    /// 期待値: 保存に成功したセッションが、その場でRootの進行中状態になる。
    func testWorkoutRootShowsSavedSessionAfterStarting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = WorkoutRootViewModel()

        viewModel.startWorkout {
            try WorkoutSessionService(context: context).startOrResume()
        }

        let active = try XCTUnwrap(viewModel.activeSession)
        let saved = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(active.id, saved.id)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: RootからWorkoutを開始した際の保存が失敗する。
    /// 期待値: 進行中表示へ切り替えず、作成途中のセッションを残さない。
    func testWorkoutRootDoesNotShowSessionWhenStartingFailsToSave() throws {
        struct SaveError: LocalizedError {
            var errorDescription: String? { "保存できませんでした" }
        }

        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = WorkoutRootViewModel()

        viewModel.startWorkout {
            try WorkoutSessionService(context: context, save: { throw SaveError() }).startOrResume()
        }

        XCTAssertNil(viewModel.activeSession)
        XCTAssertEqual(viewModel.errorMessage, "保存できませんでした")
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }

    /// テスト概要: Rootの表示状態を保存済みの進行中Workoutから更新する。
    /// 期待値: 画面へ戻った場合やアプリ再起動後に、保存済みセッションを直接表示できる。
    func testWorkoutRootRefreshesSavedActiveSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let saved = try WorkoutSessionService(context: context).startOrResume()
        let viewModel = WorkoutRootViewModel()

        viewModel.refreshActiveSession {
            try WorkoutSessionService(context: context).activeSession()
        }

        XCTAssertEqual(viewModel.activeSession?.id, saved.id)
    }

    /// テスト概要: Rootで表示中のWorkoutを破棄した後に進行中状態を更新する。
    /// 期待値: 削除済みSessionを表示し続けず、開始前状態へ戻る。
    func testWorkoutRootClearsActiveSessionAfterDiscard() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = WorkoutSessionService(context: context)
        let saved = try service.startOrResume()
        let viewModel = WorkoutRootViewModel()
        viewModel.refreshActiveSession { try service.activeSession() }
        XCTAssertEqual(viewModel.activeSession?.id, saved.id)

        try service.discard(saved)
        viewModel.refreshActiveSession { try service.activeSession() }

        XCTAssertNil(viewModel.activeSession)
    }

    /// テスト概要: 進行中Workoutがある状態で開始処理が重複して呼ばれる。
    /// 期待値: 既存セッションを表示し、新しいセッションを作成しない。
    func testWorkoutRootKeepsExistingSessionWithoutCreatingDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existing = try WorkoutSessionService(context: context).startOrResume()
        let viewModel = WorkoutRootViewModel()
        viewModel.refreshActiveSession {
            try WorkoutSessionService(context: context).activeSession()
        }

        viewModel.startWorkout {
            try WorkoutSessionService(context: context).startOrResume()
        }

        XCTAssertEqual(viewModel.activeSession?.id, existing.id)
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
        XCTAssertEqual(try WorkoutSessionService(context: context).activeSession()?.id, session.id)
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

    func testWorkoutSearchReturnsNoSessionsForEmptyOrWhitespaceQuery() {
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 0
        )

        XCTAssertTrue(WorkoutSearch.sessions(matching: "", sessions: [session], exerciseEntries: [entry]).isEmpty)
        XCTAssertTrue(WorkoutSearch.sessions(matching: "   ", sessions: [session], exerciseEntries: [entry]).isEmpty)
    }

    func testWorkoutSearchMatchesExerciseNameSnapshotPartially() {
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ラットプルダウン", primaryBodyPart: .back),
            order: 0
        )

        XCTAssertEqual(
            WorkoutSearch.sessions(matching: "プル", sessions: [session], exerciseEntries: [entry]).map(\.id),
            [session.id]
        )
    }

    func testWorkoutSearchExcludesActiveSession() {
        let session = WorkoutSession()
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 0
        )

        XCTAssertTrue(
            WorkoutSearch.sessions(matching: "プレス", sessions: [session], exerciseEntries: [entry]).isEmpty
        )
    }

    func testWorkoutSearchDeduplicatesMatchingEntriesBySession() {
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let entries = ["ベンチプレス", "ダンベルプレス"].enumerated().map { order, name in
            ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: name, primaryBodyPart: .chest),
                order: order
            )
        }

        let results = WorkoutSearch.sessions(
            matching: "プレス",
            sessions: [session],
            exerciseEntries: entries
        )

        XCTAssertEqual(results.map(\.id), [session.id])
    }

    func testWorkoutSearchSortsCompletedSessionsByNewestEndDate() {
        let older = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 2_000)
        )
        let newer = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 3_000)
        )
        let entries = [older, newer].map {
            ExerciseEntry(
                workoutSession: $0,
                exercise: Exercise(name: "プレス", primaryBodyPart: .chest),
                order: 0
            )
        }

        XCTAssertEqual(
            WorkoutSearch.sessions(
                matching: "プレス",
                sessions: [older, newer],
                exerciseEntries: entries
            ).map(\.id),
            [newer.id, older.id]
        )
    }

    func testWorkoutSearchReturnsNoSessionsForNonmatchingQuery() {
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 0
        )

        XCTAssertTrue(
            WorkoutSearch.sessions(matching: "スクワット", sessions: [session], exerciseEntries: [entry]).isEmpty
        )
    }

    func testWorkoutSearchUsesSnapshotAfterCurrentExerciseNameChanges() {
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let exercise = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        exercise.name = "チェストプレス"

        XCTAssertEqual(
            WorkoutSearch.sessions(matching: "ベンチ", sessions: [session], exerciseEntries: [entry]).map(\.id),
            [session.id]
        )
    }

    /// テスト概要: 多数の完了Workoutとactive WorkoutからOverviewの最近の履歴を取得する。
    /// 期待値: 完了日時が新しい3件とその種目だけが返り、履歴総数やactive Workoutの種目は混入しない。
    func testOverviewWorkoutLoaderFetchesOnlyLatestThreeCompletedWorkouts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var completedSessions: [WorkoutSession] = []

        for index in 0..<8 {
            let session = WorkoutSession(
                startedAt: Date(timeIntervalSince1970: TimeInterval(index * 100)),
                endedAt: Date(timeIntervalSince1970: TimeInterval(1_000 + index * 100))
            )
            let exercise = Exercise(name: "完了種目\(index)", primaryBodyPart: .other)
            let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
            session.exerciseEntries.append(entry)
            context.insert(session)
            context.insert(exercise)
            completedSessions.append(session)
        }
        let activeSession = WorkoutSession(startedAt: Date(timeIntervalSince1970: 10_000))
        let activeExercise = Exercise(name: "active種目", primaryBodyPart: .other)
        let activeEntry = ExerciseEntry(
            workoutSession: activeSession,
            exercise: activeExercise,
            order: 0
        )
        activeSession.exerciseEntries.append(activeEntry)
        context.insert(activeSession)
        context.insert(activeExercise)
        try context.save()

        let fetched = try OverviewWorkoutLoader.fetchRecentWorkouts(
            in: ModelContext(container)
        )

        XCTAssertEqual(
            fetched.map(\.id),
            completedSessions.reversed().prefix(3).map(\.id)
        )
        XCTAssertEqual(fetched.flatMap(\.exerciseEntries).count, 3)
        XCTAssertEqual(
            Set(fetched.flatMap(\.exerciseEntries).map(\.exerciseNameSnapshot)),
            Set(["完了種目5", "完了種目6", "完了種目7"])
        )
        XCTAssertFalse(
            fetched.flatMap(\.exerciseEntries).contains {
                $0.exerciseNameSnapshot == "active種目"
            }
        )
    }

    /// テスト概要: Overviewの最近の履歴を0件と3件未満のストアから取得する。
    /// 期待値: 空ストアでは空配列となり、2件では完了日時の降順で両方が返る。
    func testOverviewWorkoutLoaderHandlesEmptyAndFewerThanThreeWorkouts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        XCTAssertTrue(try OverviewWorkoutLoader.fetchRecentWorkouts(in: context).isEmpty)

        let older = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let newer = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 300),
            endedAt: Date(timeIntervalSince1970: 400)
        )
        context.insert(newer)
        context.insert(older)
        try context.save()

        XCTAssertEqual(
            try OverviewWorkoutLoader.fetchRecentWorkouts(in: context).map(\.id),
            [newer.id, older.id]
        )
    }

    /// テスト概要: 完了日時と開始日時が同じWorkoutをOverview用に取得する。
    /// 期待値: UUID昇順を最終条件として毎回同じ3件が返る。
    func testOverviewWorkoutLoaderUsesStableIDTieBreak() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ids = try [
            "10000000-0000-4000-8000-000000000004",
            "10000000-0000-4000-8000-000000000002",
            "10000000-0000-4000-8000-000000000001",
            "10000000-0000-4000-8000-000000000003",
        ].map { try XCTUnwrap(UUID(uuidString: $0)) }
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = Date(timeIntervalSince1970: 2_000)
        for id in ids {
            context.insert(WorkoutSession(id: id, startedAt: startedAt, endedAt: endedAt))
        }
        try context.save()

        XCTAssertEqual(
            try OverviewWorkoutLoader.fetchRecentWorkouts(in: context).map(\.id.uuidString),
            [
                "10000000-0000-4000-8000-000000000001",
                "10000000-0000-4000-8000-000000000002",
                "10000000-0000-4000-8000-000000000003",
            ]
        )
    }

    /// テスト概要: 当月4件、前月1件、active 1件からOverviewの月間統計対象を取得する。
    /// 期待値: 当月の完了4件とその種目だけで集計され、最近の履歴の3件制限を受けない。
    func testOverviewWorkoutLoaderKeepsAllMonthlyWorkoutsForStats() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let referenceDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))
        )
        var monthlySessions: [WorkoutSession] = []

        for day in 1...4 {
            let startedAt = try XCTUnwrap(
                calendar.date(from: DateComponents(year: 2026, month: 9, day: day))
            )
            let session = WorkoutSession(
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(600)
            )
            let exercise = Exercise(name: "当月種目\(day)", primaryBodyPart: .other)
            session.exerciseEntries.append(
                ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
            )
            context.insert(session)
            context.insert(exercise)
            monthlySessions.append(session)
        }
        let previousStart = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))
        )
        let previous = WorkoutSession(
            startedAt: previousStart,
            endedAt: previousStart.addingTimeInterval(600)
        )
        let previousExercise = Exercise(name: "前月種目", primaryBodyPart: .other)
        previous.exerciseEntries.append(
            ExerciseEntry(workoutSession: previous, exercise: previousExercise, order: 0)
        )
        let active = WorkoutSession(startedAt: referenceDate)
        let activeExercise = Exercise(name: "active種目", primaryBodyPart: .other)
        active.exerciseEntries.append(
            ExerciseEntry(workoutSession: active, exercise: activeExercise, order: 0)
        )
        context.insert(previous)
        context.insert(previousExercise)
        context.insert(active)
        context.insert(activeExercise)
        try context.save()

        let fetched = try OverviewWorkoutLoader.fetchMonthlyWorkouts(
            containing: referenceDate,
            calendar: calendar,
            in: ModelContext(container)
        )
        let entries = fetched.flatMap(\.exerciseEntries)
        let stats = OverviewStats(sessions: fetched, now: referenceDate, calendar: calendar)

        XCTAssertEqual(Set(fetched.map(\.id)), Set(monthlySessions.map(\.id)))
        XCTAssertEqual(stats.workoutCount, 4)
        XCTAssertEqual(stats.duration, 2_400)
        XCTAssertEqual(entries.count, 4)
        XCTAssertFalse(entries.contains { $0.exerciseNameSnapshot == "前月種目" })
        XCTAssertFalse(entries.contains { $0.exerciseNameSnapshot == "active種目" })
    }

    /// テスト概要: 完了Workoutの履歴行表示を生成する。
    /// 期待値: 種目はorder順のスナップショットから先頭2件と残数に要約され、所要時間と種目数が表示用文字列になる。
    func testWorkoutHistoryRowContentUsesSnapshotOrderAndSummarizesExercises() throws {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 4_120)
        )
        let fixtures = [
            ("スクワット", 2),
            ("ベンチプレス", 0),
            ("ラットプルダウン", 1),
        ]
        for fixture in fixtures {
            let exercise = Exercise(name: fixture.0, primaryBodyPart: .other)
            let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: fixture.1)
            session.exerciseEntries.append(entry)
            exercise.name = "変更後の名称"
        }

        let content = try XCTUnwrap(WorkoutHistoryRowContent(session: session))

        XCTAssertEqual(content.completedAt, Date(timeIntervalSince1970: 4_120))
        XCTAssertEqual(content.durationText, "52分")
        XCTAssertEqual(content.exerciseSummary, "ベンチプレス、ラットプルダウン、ほか1種目")
        XCTAssertEqual(content.exerciseCountText, "3種目")
    }

    /// テスト概要: 進行中Workoutの履歴行表示を生成する。
    /// 期待値: endedAtがないWorkoutは履歴表示の対象にならない。
    func testWorkoutHistoryRowContentRejectsActiveSession() {
        XCTAssertNil(WorkoutHistoryRowContent(session: WorkoutSession()))
    }

    /// テスト概要: 1時間を超える完了Workoutの所要時間表示を生成する。
    /// 期待値: 時間と分を組み合わせた表示になる。
    func testWorkoutHistoryDurationFormatsHoursAndMinutes() throws {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 4_900)
        )

        let content = try XCTUnwrap(WorkoutHistoryRowContent(session: session))

        XCTAssertEqual(content.durationText, "1時間5分")
        XCTAssertEqual(content.exerciseSummary, "")
        XCTAssertEqual(content.exerciseCountText, "0種目")
    }

    /// テスト概要: 当月の完了Workoutから総重量・日別回数・時間を集計する。
    /// 期待値: weightKg * repsの合計、同日2回の日別件数、完了分の時間だけが返る。
    func testOverviewStatsAggregatesVolumeDailyCountsAndDuration() throws {
        let calendar = utcCalendar
        let first = try makeDashboardSession(
            year: 2026, month: 9, day: 3, hour: 10, duration: 3_600, calendar: calendar, weight: 20, reps: 10)
        let second = try makeDashboardSession(
            year: 2026, month: 9, day: 3, hour: 18, duration: 1_800, calendar: calendar, weight: 30, reps: 5)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))

        let stats = OverviewStats(sessions: [first, second], now: now, calendar: calendar)

        XCTAssertEqual(stats.workoutCount, 2)
        XCTAssertEqual(stats.duration, 5_400)
        XCTAssertEqual(stats.totalVolume, 350)
        XCTAssertEqual(stats.dailyWorkoutCounts[calendar.startOfDay(for: first.startedAt)], 2)
    }

    /// テスト概要: 月初を含み、前月末・翌月初・進行中Workoutを月間集計から除外する。
    /// 期待値: 月初の完了Workoutだけを集計する。
    func testOverviewStatsUsesMonthBoundaryAndExcludesIncompleteWorkout() throws {
        let calendar = utcCalendar
        let monthStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let previous = WorkoutSession(startedAt: monthStart.addingTimeInterval(-1), endedAt: monthStart)
        let included = WorkoutSession(startedAt: monthStart, endedAt: monthStart.addingTimeInterval(600))
        let nextMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: monthStart))
        let excluded = WorkoutSession(startedAt: nextMonth, endedAt: nextMonth.addingTimeInterval(600))
        let active = WorkoutSession(startedAt: monthStart.addingTimeInterval(100))

        let stats = OverviewStats(
            sessions: [previous, included, excluded, active], now: monthStart, calendar: calendar)

        XCTAssertEqual(stats.workoutCount, 1)
        XCTAssertEqual(stats.duration, 600)
        XCTAssertEqual(stats.dailyWorkoutCounts.values.reduce(0, +), 1)
    }

    /// テスト概要: 今週が未実施でも、前週までの連続実施週を算出する。
    /// 期待値: 空の現在週で0にせず、直前の3週連続を返す。
    func testOverviewStatsStreakKeepsPreviousWeeksWhenCurrentWeekIsEmpty() throws {
        var calendar = utcCalendar
        calendar.firstWeekday = 2
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 16)))
        let sessions = [
            try makeDashboardSession(year: 2026, month: 8, day: 24, duration: 600, calendar: calendar),
            try makeDashboardSession(year: 2026, month: 8, day: 31, duration: 600, calendar: calendar),
            try makeDashboardSession(year: 2026, month: 9, day: 7, duration: 600, calendar: calendar),
        ]

        let stats = OverviewStats(sessions: sessions, now: now, calendar: calendar)

        XCTAssertEqual(stats.streak, 3)
    }

    /// テスト概要: 過去最高を超えた同一種目の月内WorkoutをPRとして判定する。
    /// 期待値: 同一Workout内の最終最高重量を採用し、過去最高との差を返す。
    func testOverviewStatsDetectsLatestPersonalRecord() throws {
        let calendar = utcCalendar
        let exercise = Exercise(name: "レッグプレス", primaryBodyPart: .legs)
        let previous = try makeDashboardSession(
            year: 2026, month: 8, day: 20, duration: 600, calendar: calendar, exercise: exercise, weights: [60])
        let record = try makeDashboardSession(
            year: 2026, month: 9, day: 10, duration: 600, calendar: calendar, exercise: exercise, weights: [65, 72])
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))

        let stats = OverviewStats(sessions: [record, previous], now: now, calendar: calendar)

        XCTAssertEqual(stats.personalRecord?.exerciseName, "レッグプレス")
        XCTAssertEqual(stats.personalRecord?.weight, 72)
        XCTAssertEqual(stats.personalRecord?.improvement, 12)
    }

    /// テスト概要: 過去最高ではないが直前Workoutより伸びた重量を判定する。
    /// 期待値: PRとは重複せず、直前Workoutとの差を記録の更新として返す。
    func testOverviewStatsDetectsImprovementWithoutPersonalRecord() throws {
        let calendar = utcCalendar
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let best = try makeDashboardSession(
            year: 2026, month: 7, day: 1, duration: 600, calendar: calendar, exercise: exercise, weights: [80])
        let previous = try makeDashboardSession(
            year: 2026, month: 8, day: 20, duration: 600, calendar: calendar, exercise: exercise, weights: [65])
        let improved = try makeDashboardSession(
            year: 2026, month: 9, day: 10, duration: 600, calendar: calendar, exercise: exercise, weights: [68])
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))

        let stats = OverviewStats(sessions: [improved, best, previous], now: now, calendar: calendar)

        XCTAssertNil(stats.personalRecord)
        XCTAssertEqual(stats.improvement?.exerciseName, "チェストプレス")
        XCTAssertEqual(stats.improvement?.improvement, 3)
    }

    /// テスト概要: 履歴がない月の集計を生成する。
    /// 期待値: 全指標が0となり、ハイライトと日別記録が空になる。
    func testOverviewStatsEmptyState() throws {
        let calendar = utcCalendar
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))

        let stats = OverviewStats(sessions: [], now: now, calendar: calendar)

        XCTAssertEqual(stats.workoutCount, 0)
        XCTAssertEqual(stats.totalVolume, 0)
        XCTAssertEqual(stats.durationText, "0分")
        XCTAssertEqual(stats.streak, 0)
        XCTAssertTrue(stats.dailyWorkoutCounts.isEmpty)
        XCTAssertNil(stats.personalRecord)
        XCTAssertNil(stats.improvement)
    }

    /// テスト概要: 同一Exerciseの完了履歴を全期間で集約する。
    /// 期待値: 最大重量と最終実施日を採用し、最終実施日が同じカードは種目名で安定して並ぶ。
    func testExerciseOverviewCardBuilderAggregatesByExerciseAndSortsStably() {
        let bench = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let squat = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let contents = ExerciseOverviewCardBuilder.build(sessions: [
            makeExerciseOverviewSession(exercise: bench, completedAt: 300, weights: [45, 55]),
            makeExerciseOverviewSession(exercise: bench, completedAt: 100, weights: [50]),
            makeExerciseOverviewSession(exercise: squat, completedAt: 300, weights: [80]),
        ])

        XCTAssertEqual(contents.map(\.exerciseName), ["スクワット", "ベンチプレス"])
        let benchContent = contents.first { $0.exerciseID == bench.id }
        XCTAssertEqual(benchContent?.currentBestWeightKg, 55)
        XCTAssertEqual(benchContent?.latestCompletedAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(benchContent?.recentMaxWeightPoints.count, 2)
    }

    /// テスト概要: 1 Workout中の同一種目と長い履歴をスパークラインへ変換する。
    /// 期待値: Workoutごとに最大重量1点とし、直近5件だけを古い順に返す。
    func testExerciseOverviewCardBuilderUsesOneChronologicalPointPerWorkoutAndLimitsToFive() {
        let exercise = Exercise(name: "レッグプレス", primaryBodyPart: .legs)
        var sessions = (1...6).map {
            makeExerciseOverviewSession(
                exercise: exercise,
                completedAt: TimeInterval($0 * 100),
                weights: [Double($0 * 10)]
            )
        }
        let newest = makeExerciseOverviewSession(exercise: exercise, completedAt: 700, weights: [65])
        let duplicate = ExerciseEntry(workoutSession: newest, exercise: exercise, order: 1)
        duplicate.setEntries = [SetEntry(exerciseEntry: duplicate, order: 0, weightKg: 75, reps: 8)]
        newest.exerciseEntries.append(duplicate)
        sessions.append(newest)

        let content = ExerciseOverviewCardBuilder.build(sessions: sessions).first

        XCTAssertEqual(content?.recentMaxWeightPoints.map(\.maxWeightKg), [30, 40, 50, 60, 75])
        XCTAssertEqual(
            content?.recentMaxWeightPoints.map(\.completedAt),
            [300, 400, 500, 600, 700].map(Date.init(timeIntervalSince1970:))
        )
    }

    /// テスト概要: 最新Workoutにだけ自己ベストバッジを表示する条件を確認する。
    /// 期待値: 初回と同値更新は除外し、過去最大を上回る場合だけ自己ベストになる。
    func testExerciseOverviewCardBuilderPersonalRecordRequiresStrictImprovementAfterFirstRecord() {
        let firstOnly = Exercise(name: "初回", primaryBodyPart: .other)
        let tied = Exercise(name: "同値", primaryBodyPart: .other)
        let improved = Exercise(name: "更新", primaryBodyPart: .other)
        let contents = ExerciseOverviewCardBuilder.build(sessions: [
            makeExerciseOverviewSession(exercise: firstOnly, completedAt: 100, weights: [50]),
            makeExerciseOverviewSession(exercise: tied, completedAt: 100, weights: [50]),
            makeExerciseOverviewSession(exercise: tied, completedAt: 200, weights: [50]),
            makeExerciseOverviewSession(exercise: improved, completedAt: 100, weights: [50]),
            makeExerciseOverviewSession(exercise: improved, completedAt: 200, weights: [55]),
        ])

        XCTAssertFalse(contents.first { $0.exerciseID == firstOnly.id }?.isLatestPersonalRecord ?? true)
        XCTAssertFalse(contents.first { $0.exerciseID == tied.id }?.isLatestPersonalRecord ?? true)
        XCTAssertTrue(contents.first { $0.exerciseID == improved.id }?.isLatestPersonalRecord ?? false)
    }

    /// テスト概要: 未完了Workoutと有効セットを持たない種目を除外する。
    /// 期待値: 完了済みかつ重量・回数が妥当なセットを持つ種目だけが表示対象になる。
    func testExerciseOverviewCardBuilderExcludesIncompleteAndInvalidRecords() {
        let included = Exercise(name: "記録あり", primaryBodyPart: .other)
        let incomplete = Exercise(name: "未完了", primaryBodyPart: .other)
        let invalid = Exercise(name: "記録なし", primaryBodyPart: .other)
        let invalidSession = makeExerciseOverviewSession(
            exercise: invalid, completedAt: 300, weights: [-10], reps: 0)

        let contents = ExerciseOverviewCardBuilder.build(sessions: [
            makeExerciseOverviewSession(exercise: included, completedAt: 100, weights: [20]),
            makeExerciseOverviewSession(
                exercise: incomplete, completedAt: 200, weights: [100], isCompleted: false),
            invalidSession,
        ])

        XCTAssertEqual(contents.map(\.exerciseID), [included.id])
        XCTAssertTrue(ExerciseOverviewCardBuilder.build(sessions: []).isEmpty)
    }

    /// テスト概要: 自重種目の全有効セットが0kgである場合を集計する。
    /// 期待値: 最大重量は0kgのまま保持し、重量スパークラインを表示しない。
    func testExerciseOverviewCardBuilderTreatsAllZeroWeightSetsAsBodyweight() {
        let exercise = Exercise(name: "プッシュアップ", primaryBodyPart: .chest)
        let content = ExerciseOverviewCardBuilder.build(sessions: [
            makeExerciseOverviewSession(exercise: exercise, completedAt: 100, weights: [0, 0]),
            makeExerciseOverviewSession(exercise: exercise, completedAt: 200, weights: [0]),
        ]).first

        XCTAssertEqual(content?.currentBestWeightKg, 0)
        XCTAssertFalse(content?.showsWeightSparkline ?? true)
        XCTAssertEqual(content?.recentMaxWeightPoints.map(\.maxWeightKg), [0, 0])
    }

    /// テスト概要: 重量種目カードのVoiceOver読み上げに直近5件の推移を含める。
    /// 期待値: Pointは古い順で読み上げ、自己ベストと現在ベストも保持する。
    func testExerciseOverviewCardAccessibilityDescriptionIncludesRecentWeightTrendInChronologicalOrder() throws {
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let content = ExerciseOverviewCardBuilder.build(
            sessions: (1...6).map {
                makeExerciseOverviewSession(
                    exercise: exercise,
                    completedAt: TimeInterval($0 * 86_400),
                    weights: [Double($0 * 10)]
                )
            }
        ).first

        let description = content?.accessibilityDescription ?? ""
        let secondPoint = Date(timeIntervalSince1970: 2 * 86_400).formatted(.dateTime.month().day())
        let thirdPoint = Date(timeIntervalSince1970: 3 * 86_400).formatted(.dateTime.month().day())
        let latestPoint = Date(timeIntervalSince1970: 6 * 86_400).formatted(.dateTime.month().day())

        XCTAssertTrue(description.contains("現在のベスト 60キログラム"))
        XCTAssertTrue(description.contains("自己ベスト"))
        XCTAssertTrue(description.contains("直近の重量推移"))
        XCTAssertFalse(description.contains("10キログラム"))
        let secondDescription = "\(secondPoint) 20キログラム"
        let thirdDescription = "\(thirdPoint) 30キログラム"
        let latestDescription = "\(latestPoint) 60キログラム"
        let secondRange = try XCTUnwrap(description.range(of: secondDescription))
        let thirdRange = try XCTUnwrap(description.range(of: thirdDescription))
        let latestRange = try XCTUnwrap(description.range(of: latestDescription))
        XCTAssertLessThan(
            secondRange.lowerBound,
            thirdRange.lowerBound
        )
        XCTAssertLessThan(
            thirdRange.lowerBound,
            latestRange.lowerBound
        )
    }

    /// テスト概要: 自重種目カードのVoiceOver読み上げには重量推移を含めない。
    /// 期待値: 自重と自己ベストの状態だけを公開し、存在しない重量情報を追加しない。
    func testExerciseOverviewCardAccessibilityDescriptionOmitsWeightTrendForBodyweight() {
        let exercise = Exercise(name: "プランク", primaryBodyPart: .core)
        let content = ExerciseOverviewCardBuilder.build(sessions: [
            makeExerciseOverviewSession(exercise: exercise, completedAt: 100, weights: [0]),
            makeExerciseOverviewSession(exercise: exercise, completedAt: 200, weights: [0]),
        ]).first

        let description = content?.accessibilityDescription ?? ""

        XCTAssertTrue(description.contains("現在のベスト 自重"))
        XCTAssertFalse(description.contains("直近の重量推移"))
        XCTAssertFalse(description.contains("キログラム"))
        XCTAssertFalse(description.contains("自己ベスト"))
    }

    func testExerciseProgressBuilderAggregatesWorkoutMetricsGrowthAndStableMaxSet() throws {
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let first = makeExerciseProgressSession(
            exercise: exercise,
            completedAt: 100,
            sets: [(weight: 27, reps: 10), (weight: 27, reps: 8)]
        )
        let second = makeExerciseProgressSession(
            exercise: exercise,
            completedAt: 200,
            sets: [(weight: 30, reps: 6), (weight: 30, reps: 12)]
        )
        let tie = makeExerciseProgressSession(
            exercise: exercise,
            completedAt: 300,
            sets: [(weight: 30, reps: 9)]
        )
        let final = makeExerciseProgressSession(
            exercise: exercise,
            completedAt: 400,
            sets: [(weight: 32, reps: 5), (weight: 20, reps: 10)]
        )

        let stats = try XCTUnwrap(
            ExerciseProgressBuilder.build(
                exerciseID: exercise.id,
                entries: [first, second, tie, final].flatMap(\.exerciseEntries)
            ))

        XCTAssertEqual(stats.firstBest, 27)
        XCTAssertEqual(stats.currentBest, 32)
        XCTAssertEqual(stats.growthAmount, 5)
        XCTAssertEqual(stats.growthPercentage ?? 0, 18.5185, accuracy: 0.001)
        XCTAssertEqual(stats.personalRecordDate, Date(timeIntervalSince1970: 400))
        XCTAssertEqual(stats.points.map(\.maxWeightKg), [27, 30, 30, 32])
        XCTAssertEqual(stats.points.map(\.volumeKg), [486, 540, 270, 360])
        XCTAssertEqual(stats.points.map(\.totalReps), [18, 18, 9, 15])
        XCTAssertEqual(stats.points.map(\.isPersonalRecord), [false, true, false, true])
        XCTAssertEqual(stats.points[1].maxWeightReps, 6)
        XCTAssertEqual(stats.recentRecords.map(\.completedAt), [400, 300, 200].map(Date.init(timeIntervalSince1970:)))
    }

    func testExerciseProgressBuilderExcludesIncompleteAndInvalidSets() throws {
        let exercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let completed = makeExerciseProgressSession(
            exercise: exercise,
            completedAt: 100,
            sets: [(weight: 40, reps: 10), (weight: -1, reps: 10), (weight: 50, reps: 0)]
        )
        let incomplete = makeExerciseProgressSession(
            exercise: exercise,
            completedAt: 200,
            sets: [(weight: 100, reps: 10)],
            isCompleted: false
        )
        let stats = try XCTUnwrap(
            ExerciseProgressBuilder.build(
                exerciseID: exercise.id,
                entries: completed.exerciseEntries + incomplete.exerciseEntries
            ))

        XCTAssertEqual(stats.points.count, 1)
        XCTAssertEqual(stats.currentBest, 40)
        XCTAssertEqual(stats.growthAmount, 0)
        XCTAssertFalse(stats.points[0].isPersonalRecord)
        XCTAssertTrue(stats.recentRecords.count == 1)
    }

    func testExerciseProgressBuilderHandlesBodyweightAndEmptyHistoryWithoutPercentage() throws {
        let exercise = Exercise(name: "プッシュアップ", primaryBodyPart: .chest)
        let bodyweight = makeExerciseProgressSession(
            exercise: exercise,
            completedAt: 100,
            sets: [(weight: 0, reps: 12), (weight: 0, reps: 8)]
        )
        let stats = try XCTUnwrap(
            ExerciseProgressBuilder.build(exerciseID: exercise.id, entries: bodyweight.exerciseEntries)
        )

        XCTAssertEqual(stats.currentBest, 0)
        XCTAssertEqual(stats.firstBest, 0)
        XCTAssertEqual(stats.growthAmount, 0)
        XCTAssertNil(stats.growthPercentage)
        XCTAssertEqual(stats.points.first?.volumeKg, 0)
        XCTAssertEqual(stats.points.first?.totalReps, 20)
        XCTAssertEqual(stats.points.first?.maxWeightReps, 12)

        let emptyExercise = Exercise(name: "未記録", primaryBodyPart: .other)
        let emptySession = makeExerciseProgressSession(
            exercise: emptyExercise,
            completedAt: 200,
            sets: [(weight: -1, reps: 0)]
        )
        let empty = try XCTUnwrap(
            ExerciseProgressBuilder.build(
                exerciseID: emptyExercise.id,
                entries: emptySession.exerciseEntries
            ))
        XCTAssertTrue(empty.points.isEmpty)
        XCTAssertNil(empty.currentBest)
        XCTAssertTrue(empty.recentRecords.isEmpty)
    }

    /// 月間factsがOverviewStatsの値を再利用し、月内の有効な種目頻度だけを決定論的に集計する。
    func testMonthlyInsightFactsUsesOverviewStatsAndMonthlyWorkoutFrequency() throws {
        let calendar = utcCalendar
        let legPress = Exercise(
            id: try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000001")),
            name: "レッグプレス",
            primaryBodyPart: .legs
        )
        let chestPress = Exercise(
            id: try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000002")),
            name: "チェストプレス",
            primaryBodyPart: .chest
        )
        let oldLeg = try makeDashboardSession(
            year: 2026, month: 8, day: 10, duration: 600, calendar: calendar,
            exercise: legPress, weights: [60])
        let bestChest = try makeDashboardSession(
            year: 2026, month: 7, day: 10, duration: 600, calendar: calendar,
            exercise: chestPress, weights: [80])
        let oldChest = try makeDashboardSession(
            year: 2026, month: 8, day: 12, duration: 600, calendar: calendar,
            exercise: chestPress, weights: [50])
        let first = try makeDashboardSession(
            year: 2026, month: 9, day: 3, duration: 1_200, calendar: calendar,
            weight: 65, reps: 10, exercise: legPress)
        let duplicateEntry = ExerciseEntry(workoutSession: first, exercise: legPress, order: 1)
        duplicateEntry.setEntries.append(
            SetEntry(exerciseEntry: duplicateEntry, order: 0, weightKg: 40, reps: 10)
        )
        first.exerciseEntries.append(duplicateEntry)
        let second = try makeDashboardSession(
            year: 2026, month: 9, day: 5, duration: 1_800, calendar: calendar,
            weight: 70, reps: 5, exercise: legPress)
        let chestEntry = ExerciseEntry(workoutSession: second, exercise: chestPress, order: 1)
        chestEntry.setEntries.append(
            SetEntry(exerciseEntry: chestEntry, order: 0, weightKg: 55, reps: 10)
        )
        second.exerciseEntries.append(chestEntry)
        let nextMonth = try makeDashboardSession(
            year: 2026, month: 10, day: 1, duration: 600, calendar: calendar,
            exercise: chestPress, weights: [90])
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))
        let sessions = [oldLeg, bestChest, oldChest, first, second, nextMonth]
        let stats = OverviewStats(sessions: sessions, now: now, calendar: calendar)

        let facts = MonthlyInsightFactsBuilder.build(
            stats: stats, sessions: sessions, calendar: calendar)

        XCTAssertEqual(facts.month, stats.month)
        XCTAssertEqual(facts.workoutCount, stats.workoutCount)
        XCTAssertEqual(facts.totalDuration, stats.duration)
        XCTAssertEqual(facts.totalVolume, stats.totalVolume)
        XCTAssertEqual(facts.activeDays, 2)
        XCTAssertEqual(facts.streakWeeks, stats.streak)
        XCTAssertEqual(facts.personalRecord?.exerciseName, stats.personalRecord?.exerciseName)
        XCTAssertEqual(facts.personalRecord?.weight, stats.personalRecord?.weight)
        XCTAssertEqual(facts.improvement?.exerciseName, stats.improvement?.exerciseName)
        XCTAssertEqual(facts.improvement?.improvement, stats.improvement?.improvement)
        XCTAssertEqual(
            facts.mostFrequentExercise,
            MonthlyInsightExerciseFrequencyFact(exerciseName: "レッグプレス", workoutCount: 2)
        )
    }

    func testMonthlyInsightViewModelSkipsEmptyAndIneligibleSingleWorkout() async {
        let generator = CountingMonthlyInsightGenerator()
        let viewModel = MonthlyInsightViewModel()

        await viewModel.generate(facts: monthlyFacts(workoutCount: 0), using: generator)
        await viewModel.generate(facts: monthlyFacts(workoutCount: 1), using: generator)

        XCTAssertEqual(generator.callCount, 0)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testMonthlyInsightViewModelHidesFailureAndUnavailableResults() async {
        let failed = MonthlyInsightViewModel()
        await failed.generate(facts: monthlyFacts(), using: FailingMonthlyInsightGenerator())
        XCTAssertEqual(failed.state, .failed)
        XCTAssertNil(failed.insight)

        let unavailable = MonthlyInsightViewModel()
        await unavailable.generate(
            facts: monthlyFacts(), using: UnavailableMonthlyInsightTestGenerator())
        XCTAssertEqual(unavailable.state, .failed)
        XCTAssertNil(unavailable.insight)
    }

    func testMonthlyInsightViewModelCachesFactsAndGeneratesForChangedMonth() async {
        let generator = CountingMonthlyInsightGenerator()
        let viewModel = MonthlyInsightViewModel()
        let september = monthlyFacts()
        let october = monthlyFacts(month: september.month.addingTimeInterval(31 * 86_400))

        await viewModel.generate(facts: september, using: generator)
        await viewModel.generate(facts: september, using: generator)
        await viewModel.generate(facts: october, using: generator)
        await viewModel.generate(facts: september, using: generator)

        XCTAssertEqual(generator.callCount, 2)
        XCTAssertEqual(viewModel.insight?.message, "2回")
    }

    func testMonthlyInsightCancellationCannotPublishOldMonthResult() async {
        let viewModel = MonthlyInsightViewModel()
        let september = monthlyFacts()
        let october = monthlyFacts(month: september.month.addingTimeInterval(31 * 86_400))
        let oldTask = Task {
            await viewModel.generate(facts: september, using: DelayedMonthlyInsightGenerator())
        }
        while viewModel.state != .generating {
            await Task.yield()
        }
        oldTask.cancel()
        await viewModel.generate(facts: october, using: CountingMonthlyInsightGenerator())
        await oldTask.value

        XCTAssertEqual(viewModel.insight?.message, "2回")
    }

    private func monthlyFacts(
        month: Date = Date(timeIntervalSince1970: 1_788_652_800),
        workoutCount: Int = 2
    ) -> MonthlyInsightFacts {
        MonthlyInsightFacts(
            month: month,
            workoutCount: workoutCount,
            totalDuration: 1_200,
            totalVolume: 1_000,
            activeDays: workoutCount,
            streakWeeks: workoutCount > 1 ? 2 : 0,
            personalRecord: nil,
            improvement: nil,
            mostFrequentExercise: workoutCount > 1
                ? MonthlyInsightExerciseFrequencyFact(
                    exerciseName: "テスト種目", workoutCount: workoutCount)
                : nil
        )
    }

    /// テスト概要: 完了Workoutの詳細表示内容を順不同の種目・セットから生成する。
    /// 期待値: 種目とセットがorder順になり、変更前の種目名スナップショットと期間が使われる。
    func testWorkoutDetailContentUsesDurationSnapshotAndEntryOrder() throws {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 4_120)
        )
        let laterExercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let firstExercise = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let laterEntry = ExerciseEntry(
            workoutSession: session,
            exercise: laterExercise,
            order: 1
        )
        let firstEntry = ExerciseEntry(
            workoutSession: session,
            exercise: firstExercise,
            order: 0
        )
        firstEntry.setEntries = [
            SetEntry(exerciseEntry: firstEntry, order: 1, weightKg: 42.5, reps: 8),
            SetEntry(exerciseEntry: firstEntry, order: 0, weightKg: 40, reps: 10),
        ]
        session.exerciseEntries = [laterEntry, firstEntry]
        firstExercise.name = "変更後の名称"

        let content = WorkoutDetailContent(session: session)

        XCTAssertEqual(content.duration, 3_120)
        XCTAssertEqual(content.durationText, "52分")
        XCTAssertEqual(content.exercises.map(\.name), ["ベンチプレス", "スクワット"])
        XCTAssertEqual(content.exercises.first?.sets.map(\.number), [1, 2])
        XCTAssertEqual(content.exercises.first?.sets.map(\.weightKg), [40, 42.5])
        XCTAssertEqual(content.exercises.first?.sets.map(\.reps), [10, 8])
    }

    /// テスト概要: 整数、小数、0の保存重量を詳細表示内容へ変換する。
    /// 期待値: Viewが共通Formatterで表示できるよう、保存重量の数値がそのまま保持される。
    func testWorkoutDetailContentKeepsSavedWeightValuesForSharedFormatting() throws {
        let session = WorkoutSession(endedAt: Date())
        let exercise = Exercise(name: "テスト種目", primaryBodyPart: .other)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        entry.setEntries = [
            SetEntry(exerciseEntry: entry, order: 0, weightKg: 40, reps: 1),
            SetEntry(exerciseEntry: entry, order: 1, weightKg: 7.5, reps: 1),
            SetEntry(exerciseEntry: entry, order: 2, weightKg: 22.5, reps: 1),
            SetEntry(exerciseEntry: entry, order: 3, weightKg: 0, reps: 1),
        ]
        session.exerciseEntries = [entry]

        let content = WorkoutDetailContent(session: session)

        XCTAssertEqual(
            content.exercises.first?.sets.map(\.weightKg),
            [40, 7.5, 22.5, 0]
        )
    }

    /// テスト概要: 現在の種目と同じExerciseを持つ完了Workoutを検索する。
    /// 期待値: 現在Workoutより前に完了したWorkoutの記録を返す。
    func testPreviousRecordReturnsLatestCompletedWorkoutForSameExercise() throws {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 300, exercise: exercise)
        let previous = makeWorkout(startedAt: 200, endedAt: 250, exercise: exercise)
        let unrelatedExercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let unrelated = makeWorkout(
            startedAt: 250,
            endedAt: 275,
            exercise: unrelatedExercise
        )

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [current, unrelated, previous]
        )

        XCTAssertEqual(result?.startedAt, previous.startedAt)
    }

    /// テスト概要: 現在のExerciseEntryを作る前にExerciseから前回記録を検索する。
    /// 期待値: 同じExerciseを持つ直近の完了Workoutを返し、空Entryを必要としない。
    func testPreviousRecordCanBeFoundBeforeExerciseEntryCreation() {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = WorkoutSession(startedAt: Date(timeIntervalSince1970: 300))
        let previous = makeWorkout(startedAt: 200, endedAt: 250, exercise: exercise)

        let result = PreviousWorkoutRecordContent.find(
            for: exercise,
            in: current,
            sessions: [current, previous]
        )

        XCTAssertEqual(result?.startedAt, previous.startedAt)
        XCTAssertTrue(current.exerciseEntries.isEmpty)
    }

    func testPreviousRecordChoosesNewestInsteadOfOlderWorkout() throws {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 400, exercise: exercise)
        let older = makeWorkout(startedAt: 100, endedAt: 150, exercise: exercise)
        let newer = makeWorkout(startedAt: 300, endedAt: 350, exercise: exercise)

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [older, current, newer]
        )

        XCTAssertEqual(result?.startedAt, newer.startedAt)
    }

    func testPreviousRecordExcludesActiveWorkout() throws {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 400, exercise: exercise)
        let completed = makeWorkout(startedAt: 200, endedAt: 250, exercise: exercise)
        let active = makeWorkout(startedAt: 300, exercise: exercise)

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [active, completed]
        )

        XCTAssertEqual(result?.startedAt, completed.startedAt)
    }

    func testPreviousRecordDoesNotMixDifferentExercise() throws {
        let target = Exercise(name: "同名種目", primaryBodyPart: .back)
        let different = Exercise(name: "同名種目", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 300, exercise: target)
        let previous = makeWorkout(startedAt: 200, endedAt: 250, exercise: different)

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [previous]
        )

        XCTAssertNil(result)
    }

    func testPreviousRecordReturnsSetsInOrder() throws {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 300, exercise: exercise)
        let previous = makeWorkout(
            startedAt: 200,
            endedAt: 250,
            exercise: exercise,
            sets: [(2, 42.5, 8), (0, 40, 10), (1, 40, 10)]
        )

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [previous]
        )

        XCTAssertEqual(result?.setEntries.map(\.order), [0, 1, 2])
    }

    func testPreviousRecordSafelyReturnsNilWhenNoRecordExists() throws {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 300, exercise: exercise)

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: []
        )

        XCTAssertNil(result)
    }

    func testPreviousRecordExcludesWorkoutStartingInFuture() throws {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 300, exercise: exercise)
        let previous = makeWorkout(startedAt: 200, endedAt: 250, exercise: exercise)
        let future = makeWorkout(startedAt: 400, endedAt: 450, exercise: exercise)

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [future, previous]
        )

        XCTAssertEqual(result?.startedAt, previous.startedAt)
    }

    func testPreviousRecordReturnsEverySetWithoutSummarizing() throws {
        let exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let current = makeWorkout(startedAt: 300, exercise: exercise)
        let previous = makeWorkout(
            startedAt: 200,
            endedAt: 250,
            exercise: exercise,
            sets: [(0, 40, 10), (1, 40, 10), (2, 40, 8), (3, 42.5, 8)]
        )

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [previous]
        )

        XCTAssertEqual(result?.setEntries.count, 4)
        XCTAssertEqual(result?.setEntries.map(\.reps), [10, 10, 8, 8])
    }

    func testPreviousRecordPreservesSavedExerciseNameSnapshot() throws {
        let exercise = Exercise(name: "保存時の種目名", primaryBodyPart: .back)
        let previous = makeWorkout(startedAt: 200, endedAt: 250, exercise: exercise)
        exercise.name = "現在の種目名"
        let current = makeWorkout(startedAt: 300, exercise: exercise)

        let result = PreviousWorkoutRecordContent.find(
            for: try XCTUnwrap(current.exerciseEntries.first),
            in: current,
            sessions: [previous]
        )

        XCTAssertEqual(result?.exerciseNameSnapshot, "保存時の種目名")
    }

    private func makeWorkout(
        startedAt: TimeInterval,
        endedAt: TimeInterval? = nil,
        exercise: Exercise,
        sets: [(order: Int, weight: Double, reps: Int)] = []
    ) -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: startedAt),
            endedAt: endedAt.map(Date.init(timeIntervalSince1970:))
        )
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        session.exerciseEntries.append(entry)
        exercise.exerciseEntries.append(entry)
        for values in sets {
            let setEntry = SetEntry(
                exerciseEntry: entry,
                order: values.order,
                weightKg: values.weight,
                reps: values.reps
            )
            entry.setEntries.append(setEntry)
        }
        return session
    }

    /// テスト概要: 入力画面と履歴詳細で共有するセット表示規則を数値へ適用する。
    /// 期待値: セット番号と回数は数値のみ、重量は小数点以下2桁の数値とkgで表示される。
    func testWorkoutSetDisplayFormatterUsesSharedColumnFormats() {
        XCTAssertEqual(WorkoutSetDisplayFormatter.setNumber(1), "1")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(18), "18.00 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(4.5), "4.50 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(100), "100.00 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.reps(12), "12")
    }

    /// テスト概要: 一覧セル向けに保存済みセットを要約する。
    /// 期待値: 同一内容なら重量・回数・セット数を表示し、内容が異なる場合はセット数だけを表示する。
    func testWorkoutSetDisplayFormatterSummarizesSetsWithoutMisrepresentingMixedValues() {
        let entry = ExerciseEntry(
            workoutSession: WorkoutSession(),
            exercise: Exercise(name: "チェストプレス", primaryBodyPart: .chest),
            order: 0
        )
        let matching = (0..<3).map {
            SetEntry(exerciseEntry: entry, order: $0, weightKg: 32, reps: 10)
        }
        let mixed = [
            SetEntry(exerciseEntry: entry, order: 0, weightKg: 30, reps: 10),
            SetEntry(exerciseEntry: entry, order: 1, weightKg: 32, reps: 8),
        ]

        XCTAssertEqual(
            WorkoutSetDisplayFormatter.summary(prefix: "今回", setEntries: matching),
            "今回 32.00 kg × 10 × 3"
        )
        XCTAssertEqual(
            WorkoutSetDisplayFormatter.summary(prefix: "前回", setEntries: mixed),
            "前回 2セット"
        )
        XCTAssertEqual(
            WorkoutSetDisplayFormatter.summary(prefix: "今回", setEntries: []),
            "今回 入力中"
        )
    }

    /// テスト概要: 保存済み重量を小数点以下2桁固定の表示文字列へ変換する。
    /// 期待値: 整数と小数のどちらも2桁の小数部とkgを持つ。
    func testWorkoutSetDisplayFormatterUsesTwoFractionDigitsForDisplay() {
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(40), "40.00 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(40.0), "40.00 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(42.5), "42.50 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(4.5), "4.50 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(22.25), "22.25 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(100), "100.00 kg")
        XCTAssertEqual(WorkoutSetDisplayFormatter.displayWeight(0), "0.00 kg")
    }

    /// テスト概要: 保存重量を編集開始時の入力文字列へ変換する。
    /// 期待値: 表示用とは異なり、入力しやすいよう不要な末尾ゼロを除去する。
    func testWorkoutSetDisplayFormatterRemovesTrailingZerosForEditing() {
        XCTAssertEqual(WorkoutSetDisplayFormatter.editableWeightValue(40), "40")
        XCTAssertEqual(WorkoutSetDisplayFormatter.editableWeightValue(42.5), "42.5")
        XCTAssertEqual(WorkoutSetDisplayFormatter.editableWeightValue(22.25), "22.25")
    }

    /// テスト概要: 終了日時とExercise参照が欠けたWorkoutから詳細表示内容を生成する。
    /// 期待値: 強制アンラップせず、期間はプレースホルダー、種目名はスナップショットになる。
    func testWorkoutDetailContentSafelyHandlesMissingOptionalRelationshipsAndEndDate() throws {
        let session = WorkoutSession(startedAt: Date(timeIntervalSince1970: 1_000))
        let exercise = Exercise(name: "保存時の種目名", primaryBodyPart: .other)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        entry.exercise = nil
        session.exerciseEntries = [entry]

        let content = WorkoutDetailContent(session: session)

        XCTAssertNil(content.endedAt)
        XCTAssertNil(content.duration)
        XCTAssertEqual(content.durationText, "--")
        XCTAssertEqual(content.exercises.first?.name, "保存時の種目名")
        XCTAssertTrue(content.exercises.first?.sets.isEmpty == true)
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

    /// テスト概要: 複数種目がある状態でDraft重量欄の次フォーカスを求める。
    /// 期待値: 選択中のExerciseEntry IDを維持したDraft回数欄だけが返される。
    func testWorkoutDraftWeightNextInputKeepsExerciseIdentity() {
        let focusedExerciseID = UUID()
        let otherExerciseID = UUID()

        let nextInput = WorkoutInputFocus.draftWeight(exerciseID: focusedExerciseID).nextInput(
            savedSetIDs: [],
            draftExerciseID: focusedExerciseID
        )

        XCTAssertEqual(nextInput, .draftReps(exerciseID: focusedExerciseID))
        XCTAssertNotEqual(nextInput, .draftReps(exerciseID: otherExerciseID))
    }

    /// テスト概要: 保存済みセットと未保存Draftを含む次フォーカスを順に求める。
    /// 期待値: 重量、回数、次セット重量の順で進み、最後の保存済みセットからDraftへ接続する。
    func testWorkoutInputFocusAdvancesContinuouslyAcrossSets() {
        let exerciseID = UUID()
        let setIDs = [UUID(), UUID()]

        XCTAssertEqual(
            WorkoutInputFocus.savedWeight(exerciseID: exerciseID, setID: setIDs[0]).nextInput(
                savedSetIDs: setIDs,
                draftExerciseID: exerciseID
            ),
            .savedReps(exerciseID: exerciseID, setID: setIDs[0])
        )
        XCTAssertEqual(
            WorkoutInputFocus.savedReps(exerciseID: exerciseID, setID: setIDs[0]).nextInput(
                savedSetIDs: setIDs,
                draftExerciseID: exerciseID
            ),
            .savedWeight(exerciseID: exerciseID, setID: setIDs[1])
        )
        XCTAssertEqual(
            WorkoutInputFocus.savedReps(exerciseID: exerciseID, setID: setIDs[1]).nextInput(
                savedSetIDs: setIDs,
                draftExerciseID: exerciseID
            ),
            .draftWeight(exerciseID: exerciseID)
        )
        XCTAssertEqual(
            WorkoutInputFocus.draftWeight(exerciseID: exerciseID).nextInput(
                savedSetIDs: setIDs,
                draftExerciseID: exerciseID
            ),
            .draftReps(exerciseID: exerciseID)
        )
        XCTAssertEqual(
            WorkoutInputFocus.draftReps(exerciseID: exerciseID).nextInput(
                savedSetIDs: setIDs,
                draftExerciseID: exerciseID
            ),
            .draftWeight(exerciseID: exerciseID)
        )
    }

    /// テスト概要: 保存済みセット内外へのフォーカス移動から保存境界を判定する。
    /// 期待値: 同じセットの重量から回数では保存せず、別セットまたはDraftへ移る場合だけ元セットを保存する。
    func testSavedSetCommitBoundaryIsLeavingTheSet() {
        let exerciseID = UUID()
        let firstSetID = UUID()
        let secondSetID = UUID()
        let weight = WorkoutInputFocus.savedWeight(exerciseID: exerciseID, setID: firstSetID)
        let reps = WorkoutInputFocus.savedReps(exerciseID: exerciseID, setID: firstSetID)

        XCTAssertNil(weight.savedSetToCommit(whenMovingTo: reps))
        XCTAssertEqual(
            reps.savedSetToCommit(
                whenMovingTo: .savedWeight(exerciseID: exerciseID, setID: secondSetID)
            )?.setID,
            firstSetID
        )
        XCTAssertEqual(
            reps.savedSetToCommit(whenMovingTo: .draftWeight(exerciseID: exerciseID))?.setID,
            firstSetID
        )
        XCTAssertEqual(reps.savedSetToCommit(whenMovingTo: nil)?.setID, firstSetID)
        XCTAssertNil(
            WorkoutInputFocus.draftReps(exerciseID: exerciseID)
                .savedSetToCommit(whenMovingTo: nil)
        )
    }

    /// テスト概要: 複数の保存済みセットを個別のDraftとして編集する。
    /// 期待値: 入力中は永続モデルが変化せず、Draft同士の値も混ざらない。
    func testSavedSetDraftEditingDoesNotMutateOrMixPersistentValues() {
        let entry = ExerciseEntry(
            workoutSession: WorkoutSession(),
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let first = SetEntry(exerciseEntry: entry, order: 0, weightKg: 40, reps: 10)
        let second = SetEntry(exerciseEntry: entry, order: 1, weightKg: 50, reps: 8)
        var drafts = [
            first.id: SetEntryDraft.savedValues(from: first),
            second.id: SetEntryDraft.savedValues(from: second),
        ]

        drafts[first.id]?.weight = "42.5"
        drafts[second.id]?.reps = "6"

        XCTAssertEqual(first.weightKg, 40)
        XCTAssertEqual(first.reps, 10)
        XCTAssertEqual(second.weightKg, 50)
        XCTAssertEqual(second.reps, 8)
        XCTAssertEqual(drafts[first.id], SetEntryDraft(weight: "42.5", reps: "10"))
        XCTAssertEqual(drafts[second.id], SetEntryDraft(weight: "50", reps: "6"))
    }

    /// テスト概要: 最後に表示されるDraftセットの回数入力かを判定する。
    /// 期待値: 対象ExerciseのDraft回数だけが該当し、別Exerciseや保存済みセットは該当しない。
    func testAddSetShortcutOnlyMatchesCurrentDraftReps() {
        let exerciseID = UUID()
        let otherExerciseID = UUID()
        let setID = UUID()

        XCTAssertTrue(
            WorkoutInputFocus.draftReps(exerciseID: exerciseID)
                .isDraftReps(exerciseID: exerciseID)
        )
        XCTAssertFalse(
            WorkoutInputFocus.draftReps(exerciseID: otherExerciseID)
                .isDraftReps(exerciseID: exerciseID)
        )
        XCTAssertFalse(
            WorkoutInputFocus.draftWeight(exerciseID: exerciseID)
                .isDraftReps(exerciseID: exerciseID)
        )
        XCTAssertFalse(
            WorkoutInputFocus.savedReps(exerciseID: exerciseID, setID: setID)
                .isDraftReps(exerciseID: exerciseID)
        )
    }

    /// テスト概要: 保存済みセットのフォーカス識別情報を複数種目間で比較する。
    /// 期待値: SetEntry IDだけでなくExerciseEntry IDも含めて編集対象を区別できる。
    func testSavedSetFocusIdentityIncludesExerciseAndSetIDs() {
        let firstExerciseID = UUID()
        let secondExerciseID = UUID()
        let setID = UUID()

        let first = WorkoutInputFocus.savedWeight(exerciseID: firstExerciseID, setID: setID)
        let second = WorkoutInputFocus.savedReps(exerciseID: secondExerciseID, setID: setID)

        XCTAssertNotEqual(first.savedSetIdentity, second.savedSetIdentity)
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

    /// テスト概要: 未記録種目の最初のセットを保存する。
    /// 期待値: ExerciseEntryとSetEntryが同時に作成され、先頭orderで永続化される。
    func testRecordingFirstSetCreatesEntryAndSetTogether() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let first = Exercise(name: "スクワット", primaryBodyPart: .legs)
        context.insert(session)
        context.insert(first)
        try context.save()

        let entry = try WorkoutExerciseService(context: context).recordFirstSet(
            draft: SetEntryDraft(weight: "60", reps: "10"),
            for: first,
            in: session
        )

        XCTAssertEqual(entry.exercise?.id, first.id)
        XCTAssertEqual(entry.exerciseNameSnapshot, "スクワット")
        XCTAssertEqual(entry.bodyPartSnapshot, .legs)
        XCTAssertEqual(entry.order, 0)
        XCTAssertEqual(entry.setEntries.count, 1)
        XCTAssertEqual(entry.setEntries.first?.weightKg, 60)
        XCTAssertEqual(entry.setEntries.first?.reps, 10)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 未記録種目から戻る際に有効なDraftを確定する。
    /// 期待値: ExerciseEntryとSetEntryが1件ずつ永続化される。
    func testCommittingCurrentSetCreatesFirstEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "カーフレイズ", primaryBodyPart: .legs)
        context.insert(session)
        context.insert(exercise)
        try context.save()

        let entry = try XCTUnwrap(
            WorkoutExerciseService(context: context).commitCurrentSetIfNeeded(
                draft: SetEntryDraft(weight: "5", reps: "5"),
                for: exercise,
                in: session
            )
        )

        XCTAssertEqual(entry.setEntries.count, 1)
        XCTAssertEqual(entry.setEntries.first?.weightKg, 5)
        XCTAssertEqual(entry.setEntries.first?.reps, 5)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 1セット確定済みの種目で、次の有効なDraftを確定する。
    /// 期待値: 既存セットを重複させず、2番目のセットだけが追加される。
    func testCommittingCurrentSetAppendsOnlyDraftToExistingEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "カーフレイズ", primaryBodyPart: .legs)
        context.insert(session)
        context.insert(exercise)
        try context.save()
        let service = WorkoutExerciseService(context: context)
        let entry = try XCTUnwrap(
            service.commitCurrentSetIfNeeded(
                draft: SetEntryDraft(weight: "5", reps: "5"),
                for: exercise,
                in: session
            )
        )
        XCTAssertNil(
            try service.commitCurrentSetIfNeeded(
                draft: SetEntryDraft(),
                for: exercise,
                in: session
            )
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)

        let committedEntry = try XCTUnwrap(
            service.commitCurrentSetIfNeeded(
                draft: SetEntryDraft(weight: "10", reps: "8"),
                for: exercise,
                in: session
            )
        )

        XCTAssertEqual(committedEntry.id, entry.id)
        let sets = try context.fetch(FetchDescriptor<SetEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(sets.map(\.order), [0, 1])
        XCTAssertEqual(sets.map(\.weightKg), [5, 10])
        XCTAssertEqual(sets.map(\.reps), [5, 8])
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 空または片方だけ入力されたDraftを確定しようとする。
    /// 期待値: 不完全なSetも空のExerciseEntryも保存されない。
    func testCommittingCurrentSetIgnoresEmptyAndIncompleteDrafts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "カーフレイズ", primaryBodyPart: .legs)
        context.insert(session)
        context.insert(exercise)
        try context.save()
        let service = WorkoutExerciseService(context: context)

        for draft in [
            SetEntryDraft(),
            SetEntryDraft(weight: "5", reps: ""),
            SetEntryDraft(weight: "", reps: "5"),
        ] {
            XCTAssertNil(
                try service.commitCurrentSetIfNeeded(
                    draft: draft,
                    for: exercise,
                    in: session
                )
            )
        }

        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 複数種目の最初のセットを順番に保存し、再取得する。
    /// 期待値: 最後に記録した種目が先頭になり、既存種目の相対順を保った連番が永続化される。
    func testRecordingFirstSetsPrependsAndPersistsContiguousOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercises = (0..<4).map { Exercise(name: "種目\($0)", primaryBodyPart: .other) }
        context.insert(session)
        exercises.forEach(context.insert)
        try context.save()
        let service = WorkoutExerciseService(context: context)

        for exercise in exercises {
            _ = try service.recordFirstSet(
                draft: SetEntryDraft(weight: "10", reps: "8"),
                for: exercise,
                in: session
            )
        }

        let fetchedContext = ModelContext(container)
        let fetched = try fetchedContext.fetch(FetchDescriptor<ExerciseEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(fetched.map(\.exerciseNameSnapshot), ["種目3", "種目2", "種目1", "種目0"])
        XCTAssertEqual(fetched.map(\.order), [0, 1, 2, 3])
        XCTAssertEqual(Set(fetched.map(\.order)).count, fetched.count)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: Relationshipが同じExerciseEntry IDを重複して返す状態で表示順を更新する。
    /// 期待値: 論理IDごとに一度だけorderが割り当てられ、0始まりの連番になる。
    func testMovingExerciseToFrontDeduplicatesRelationshipEntries() {
        let session = WorkoutSession()
        let first = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let second = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 1
        )
        session.exerciseEntries = [first, second, first, second]

        WorkoutExerciseService.moveToFront(second, in: session)

        XCTAssertEqual(second.order, 0)
        XCTAssertEqual(first.order, 1)
    }

    /// テスト概要: 同じ種目の最初のセットを同一セッションと別セッションへ保存する。
    /// 期待値: 同一セッションの重複だけが拒否される。
    func testDuplicateFirstSetIsRejectedOnlyWithinSameSession() throws {
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

        let draft = SetEntryDraft(weight: "0", reps: "30")
        _ = try service.recordFirstSet(draft: draft, for: exercise, in: firstSession)
        XCTAssertThrowsError(
            try service.recordFirstSet(draft: draft, for: exercise, in: firstSession)
        ) { error in
            XCTAssertEqual(error as? WorkoutExerciseError, .duplicateExercise)
        }
        XCTAssertNoThrow(
            try service.recordFirstSet(draft: draft, for: exercise, in: secondSession)
        )
    }

    /// テスト概要: 不正なDraftで未記録種目を保存しようとする。
    /// 期待値: ExerciseEntryもSetEntryも作成されず、空の実施記録が残らない。
    func testInvalidFirstSetDoesNotCreateEmptyExerciseEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "プランク", primaryBodyPart: .core)
        context.insert(session)
        context.insert(exercise)
        try context.save()

        XCTAssertThrowsError(
            try WorkoutExerciseService(context: context).recordFirstSet(
                draft: SetEntryDraft(),
                for: exercise,
                in: session
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutSetError, .invalidValues)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
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
        let entries = try exercises.map {
            try service.recordFirstSet(
                draft: SetEntryDraft(weight: "10", reps: "8"),
                for: $0,
                in: session
            )
        }

        try service.delete(entries[1], from: session)

        let remaining = try context.fetch(FetchDescriptor<ExerciseEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(remaining.map(\.exerciseNameSnapshot), ["種目2", "種目0"])
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
        XCTAssertEqual(WorkoutSessionContent.setEntries(for: exerciseEntry).count, 1)
        XCTAssertEqual(WorkoutSessionContent.draftOrder(for: exerciseEntry), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 既存種目へセットを追加する。
    /// 期待値: 更新した種目が今回のWorkoutの先頭へ移り、orderが再取得後も維持される。
    func testAddingSetMovesExerciseToFrontAndPersistsOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let first = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let updated = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 1
        )
        context.insert(first)
        context.insert(updated)
        try context.save()

        _ = try WorkoutSetService(context: context).add(
            draft: SetEntryDraft(weight: "40", reps: "10"),
            to: updated
        )

        let fetchedContext = ModelContext(container)
        let fetched = try fetchedContext.fetch(FetchDescriptor<ExerciseEntry>())
            .sorted { $0.order < $1.order }
        XCTAssertEqual(fetched.map(\.exerciseNameSnapshot), ["ベンチプレス", "スクワット"])
        XCTAssertEqual(fetched.map(\.order), [0, 1])
    }

    /// テスト概要: 既存セットを更新する。
    /// 期待値: 更新した種目が今回のWorkoutの先頭へ移り、orderが再取得後も維持される。
    func testUpdatingSetMovesExerciseToFrontAndPersistsOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let first = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let updated = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 1
        )
        let setEntry = SetEntry(
            exerciseEntry: updated,
            order: 0,
            weightKg: 40,
            reps: 10
        )
        context.insert(first)
        context.insert(setEntry)
        try context.save()

        try WorkoutSetService(context: context).update(
            setEntry,
            draft: SetEntryDraft(weight: "42.5", reps: "8")
        )

        let fetchedContext = ModelContext(container)
        let fetched = try fetchedContext.fetch(FetchDescriptor<ExerciseEntry>())
            .sorted { $0.order < $1.order }
        XCTAssertEqual(fetched.map(\.exerciseNameSnapshot), ["ベンチプレス", "スクワット"])
        XCTAssertEqual(fetched.map(\.order), [0, 1])
    }

    /// テスト概要: 保存済みセットがない種目の表示内容を、再開相当として繰り返し生成する。
    /// 期待値: 初回も再生成後もSet 1に相当する未確定Draft位置だけが返り、永続セットは増えない。
    func testWorkoutContentInitializationIsIdempotentWithoutSavedSets() {
        let session = WorkoutSession()
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 0
        )

        let first = WorkoutSessionContent(exerciseEntries: [entry])
        let resumed = WorkoutSessionContent(exerciseEntries: [entry, entry])

        XCTAssertEqual(first.exerciseEntries.map(\.id), [entry.id])
        XCTAssertEqual(resumed.exerciseEntries.map(\.id), [entry.id])
        XCTAssertEqual(WorkoutSessionContent.draftOrder(for: entry), 0)
        XCTAssertTrue(entry.setEntries.isEmpty)
    }

    /// テスト概要: 全種目から現在のWorkoutで記録済みの種目を除外し、名称検索する。
    /// 期待値: 記録済みとアーカイブ済みは表示されず、検索語に部分一致する未記録種目だけが返る。
    func testWorkoutContentFiltersAvailableExercisesWithoutDuplicates() {
        let session = WorkoutSession()
        let recorded = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let matching = Exercise(name: "ショルダープレス", primaryBodyPart: .shoulders)
        let unrelated = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let archived = Exercise(name: "旧プレス", primaryBodyPart: .chest, isArchived: true)
        let entry = ExerciseEntry(workoutSession: session, exercise: recorded, order: 0)
        let content = WorkoutSessionContent(exerciseEntries: [entry])

        let result = content.availableExercises(
            from: [recorded, matching, unrelated, archived],
            matching: "プレス"
        )

        XCTAssertEqual(result.map(\.id), [matching.id])
    }

    /// テスト概要: 複数種目と保存済みセットを持つ表示内容を、重複を含む再開時relationshipから生成する。
    /// 期待値: 種目と保存セットはIDごとに一度だけ射影され、各Draft位置は各種目の末尾orderの次になる。
    func testWorkoutContentInitializationKeepsDraftsSeparateAndSavedSetsUnchanged() {
        let session = WorkoutSession()
        let firstEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let secondEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 1
        )
        let firstSets = [
            SetEntry(exerciseEntry: firstEntry, order: 0, weightKg: 80, reps: 8),
            SetEntry(exerciseEntry: firstEntry, order: 1, weightKg: 85, reps: 5),
        ]
        firstEntry.setEntries = [firstSets[0], firstSets[1], firstSets[0]]

        for _ in 0..<3 {
            let content = WorkoutSessionContent(
                exerciseEntries: [firstEntry, secondEntry, firstEntry, secondEntry]
            )
            XCTAssertEqual(content.exerciseEntries.map(\.id), [firstEntry.id, secondEntry.id])
            XCTAssertEqual(WorkoutSessionContent.setEntries(for: firstEntry).map(\.id), firstSets.map(\.id))
            XCTAssertEqual(WorkoutSessionContent.draftOrder(for: firstEntry), 2)
            XCTAssertEqual(WorkoutSessionContent.draftOrder(for: secondEntry), 0)
        }

        XCTAssertEqual(firstSets.map(\.order), [0, 1])
        XCTAssertEqual(firstSets.map(\.weightKg), [80, 85])
        XCTAssertEqual(firstSets.map(\.reps), [8, 5])
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
        let integerDraft = SetEntryDraft.savedValues(
            from: SetEntry(exerciseEntry: exerciseEntry, order: 1, weightKg: 40, reps: 10),
            decimalSeparator: ","
        )
        let twoDigitFractionDraft = SetEntryDraft.savedValues(
            from: SetEntry(exerciseEntry: exerciseEntry, order: 2, weightKg: 22.25, reps: 6),
            decimalSeparator: ","
        )

        XCTAssertEqual(draft, SetEntryDraft(weight: "1000,5", reps: "8"))
        XCTAssertEqual(integerDraft, SetEntryDraft(weight: "40", reps: "10"))
        XCTAssertEqual(twoDigitFractionDraft, SetEntryDraft(weight: "22,25", reps: "6"))
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

    /// テスト概要: 完了済みWorkoutの既存セットを履歴編集Draftから更新する。
    /// 期待値: 重量・回数だけが更新され、日時、order、ウォームアップ状態は維持される。
    func testHistoryEditUpdatesExistingSetAndPreservesImmutableValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = Date(timeIntervalSince1970: 2_000)
        let session = WorkoutSession(startedAt: startedAt, endedAt: endedAt)
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "ベンチプレス", primaryBodyPart: .chest),
            order: 0
        )
        let setEntry = SetEntry(
            exerciseEntry: entry,
            order: 0,
            weightKg: 40,
            reps: 10,
            isWarmup: true
        )
        context.insert(setEntry)
        try context.save()
        var draft = WorkoutHistoryEditDraft(session: session)
        draft.exercises[0].sets[0].values = SetEntryDraft(weight: "42.5", reps: "8")

        try WorkoutHistoryEditService(context: context).save(draft, to: session)

        XCTAssertEqual(setEntry.weightKg, 42.5)
        XCTAssertEqual(setEntry.reps, 8)
        XCTAssertEqual(setEntry.order, 0)
        XCTAssertTrue(setEntry.isWarmup)
        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.endedAt, endedAt)
    }

    /// テスト概要: 完了済みWorkoutへ種目とセットをDraftから追加する。
    /// 期待値: 種目マスタのsnapshot、新規セットの値、末尾order、isWarmup=falseが保存される。
    func testHistoryEditAddsExerciseAndSetAtEndWithSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let firstExercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let addedExercise = Exercise(name: "デッドリフト", primaryBodyPart: .back)
        let firstEntry = ExerciseEntry(
            workoutSession: session,
            exercise: firstExercise,
            order: 0
        )
        context.insert(firstEntry)
        context.insert(addedExercise)
        context.insert(SetEntry(exerciseEntry: firstEntry, order: 0, weightKg: 60, reps: 10))
        try context.save()
        var draft = WorkoutHistoryEditDraft(session: session)

        try draft.addExercise(addedExercise)
        XCTAssertThrowsError(try draft.addExercise(addedExercise)) {
            guard
                let error = $0 as? WorkoutExerciseError,
                case .duplicateExercise = error
            else {
                return XCTFail("duplicateExercise以外のエラー: \($0)")
            }
        }
        let addedEntryID = try XCTUnwrap(draft.exercises.last?.id)
        draft.addSet(to: addedEntryID)
        draft.exercises[1].sets[0].values = SetEntryDraft(weight: "100", reps: "5")

        try WorkoutHistoryEditService(context: context).save(draft, to: session)

        let entries = session.exerciseEntries.sorted { $0.order < $1.order }
        let addedEntry = try XCTUnwrap(entries.last)
        let addedSet = try XCTUnwrap(addedEntry.setEntries.first)
        XCTAssertEqual(entries.map(\.order), [0, 1])
        XCTAssertEqual(addedEntry.exercise?.id, addedExercise.id)
        XCTAssertEqual(addedEntry.exerciseNameSnapshot, "デッドリフト")
        XCTAssertEqual(addedEntry.bodyPartSnapshot, .back)
        XCTAssertEqual(addedSet.order, 0)
        XCTAssertEqual(addedSet.weightKg, 100)
        XCTAssertEqual(addedSet.reps, 5)
        XCTAssertFalse(addedSet.isWarmup)

        let rowContent = try XCTUnwrap(WorkoutHistoryRowContent(session: session))
        XCTAssertEqual(rowContent.exerciseNames, ["スクワット", "デッドリフト"])
        XCTAssertEqual(WorkoutDetailContent(session: session).exercises.count, 2)
    }

    /// テスト概要: 履歴編集で中間セットと別の種目を削除する。
    /// 期待値: 残存セットのorderが連番になり、削除種目のSetEntryもcascade削除される。
    func testHistoryEditDeletesExerciseAndRenumbersRemainingSets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let firstEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let deletedEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "プレス", primaryBodyPart: .shoulders),
            order: 1
        )
        let firstSets = (0..<3).map {
            SetEntry(exerciseEntry: firstEntry, order: $0, weightKg: Double($0 + 1), reps: 5)
        }
        firstSets.forEach(context.insert)
        context.insert(SetEntry(exerciseEntry: deletedEntry, order: 0, weightKg: 20, reps: 8))
        try context.save()
        var draft = WorkoutHistoryEditDraft(session: session)

        draft.deleteSet(id: firstSets[1].id, from: firstEntry.id)
        draft.deleteExercise(id: deletedEntry.id)
        try WorkoutHistoryEditService(context: context).save(draft, to: session)

        XCTAssertEqual(session.exerciseEntries.map(\.id), [firstEntry.id])
        XCTAssertEqual(firstEntry.setEntries.sorted { $0.order < $1.order }.map(\.order), [0, 1])
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 2)
    }

    /// テスト概要: 履歴編集Draftへ不正値、空の種目、全削除を設定して保存する。
    /// 期待値: 既存の入力規則で各保存が拒否され、永続モデルは変更されない。
    func testHistoryEditRejectsInvalidIncompleteAndEmptyWorkout() throws {
        let invalidDrafts = [
            SetEntryDraft(weight: "-1", reps: "8"),
            SetEntryDraft(weight: "10", reps: "0"),
            SetEntryDraft(weight: "1.234", reps: "5"),
        ]

        for invalidValues in invalidDrafts {
            let container = try makeContainer()
            let context = container.mainContext
            let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
            let entry = ExerciseEntry(
                workoutSession: session,
                exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
                order: 0
            )
            let setEntry = SetEntry(exerciseEntry: entry, order: 0, weightKg: 60, reps: 10)
            context.insert(setEntry)
            try context.save()
            var draft = WorkoutHistoryEditDraft(session: session)
            draft.exercises[0].sets[0].values = invalidValues

            XCTAssertThrowsError(try WorkoutHistoryEditService(context: context).save(draft, to: session)) {
                XCTAssertEqual($0 as? WorkoutHistoryEditError, .invalidSet)
            }
            XCTAssertEqual(setEntry.weightKg, 60)
            XCTAssertEqual(setEntry.reps, 10)

            draft.deleteSet(id: setEntry.id, from: entry.id)
            XCTAssertThrowsError(try WorkoutHistoryEditService(context: context).save(draft, to: session)) {
                XCTAssertEqual($0 as? WorkoutHistoryEditError, .emptyExercise)
            }

            draft.deleteExercise(id: entry.id)
            XCTAssertThrowsError(try WorkoutHistoryEditService(context: context).save(draft, to: session)) {
                XCTAssertEqual($0 as? WorkoutHistoryEditError, .noSets)
            }
        }
    }

    /// テスト概要: 履歴編集Draftを変更して保存せず破棄する。
    /// 期待値: Draftだけが変更され、元のWorkoutモデルには一切反映されない。
    func testHistoryEditDraftDoesNotMutateWorkoutBeforeSave() throws {
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let setEntry = SetEntry(exerciseEntry: entry, order: 0, weightKg: 60, reps: 10)
        session.exerciseEntries = [entry]
        entry.setEntries = [setEntry]
        var draft = WorkoutHistoryEditDraft(session: session)

        draft.exercises[0].sets[0].values = SetEntryDraft(weight: "70", reps: "8")

        XCTAssertTrue(draft.hasChanges)
        XCTAssertEqual(setEntry.weightKg, 60)
        XCTAssertEqual(setEntry.reps, 10)
        XCTAssertEqual(session.exerciseEntries.map(\.id), [entry.id])
    }

    /// テスト概要: Draft作成後に同じWorkoutの既存セットが別の操作で更新される。
    /// 期待値: 古いDraftの保存が拒否され、介在変更とDraftの編集内容が維持される。
    func testHistoryEditRejectsStaleDraftAfterSetUpdate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let setEntry = SetEntry(exerciseEntry: entry, order: 0, weightKg: 60, reps: 10)
        context.insert(setEntry)
        try context.save()
        var draft = WorkoutHistoryEditDraft(session: session)
        draft.exercises[0].sets[0].values = SetEntryDraft(weight: "70", reps: "8")

        setEntry.weightKg = 65
        try context.save()

        XCTAssertThrowsError(try WorkoutHistoryEditService(context: context).save(draft, to: session)) {
            XCTAssertEqual($0 as? WorkoutHistoryEditError, .staleDraft)
        }
        XCTAssertEqual(setEntry.weightKg, 65)
        XCTAssertEqual(setEntry.reps, 10)
        XCTAssertEqual(draft.exercises[0].sets[0].values, SetEntryDraft(weight: "70", reps: "8"))
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: Draft作成後に同じWorkoutへ別の操作で種目とセットが追加される。
    /// 期待値: 古いDraftの保存が拒否され、追加された種目とセットが削除されない。
    func testHistoryEditRejectsStaleDraftAfterExerciseAddition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(endedAt: Date(timeIntervalSince1970: 2_000))
        let firstEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let firstSet = SetEntry(exerciseEntry: firstEntry, order: 0, weightKg: 60, reps: 10)
        context.insert(firstSet)
        try context.save()
        var draft = WorkoutHistoryEditDraft(session: session)
        draft.exercises[0].sets[0].values = SetEntryDraft(weight: "70", reps: "8")

        let addedEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "デッドリフト", primaryBodyPart: .back),
            order: 1
        )
        let addedSet = SetEntry(exerciseEntry: addedEntry, order: 0, weightKg: 100, reps: 5)
        context.insert(addedSet)
        try context.save()

        XCTAssertThrowsError(try WorkoutHistoryEditService(context: context).save(draft, to: session)) {
            XCTAssertEqual($0 as? WorkoutHistoryEditError, .staleDraft)
        }
        XCTAssertEqual(Set(session.exerciseEntries.map(\.id)), Set([firstEntry.id, addedEntry.id]))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 2)
        XCTAssertEqual(addedSet.weightKg, 100)
        XCTAssertEqual(addedSet.reps, 5)
        XCTAssertFalse(context.hasChanges)
    }

    /// テスト概要: 履歴編集の一括保存が失敗する。
    /// 期待値: 元モデルの値と編集Draftが維持され、同じDraftで再試行できる。
    func testHistoryEditSaveFailureKeepsOriginalDataAndDraft() throws {
        struct ExpectedError: Error {}

        let container = try makeContainer()
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = Date(timeIntervalSince1970: 2_000)
        let session = WorkoutSession(startedAt: startedAt, endedAt: endedAt)
        let entry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "スクワット", primaryBodyPart: .legs),
            order: 0
        )
        let setEntry = SetEntry(
            exerciseEntry: entry,
            order: 0,
            weightKg: 60,
            reps: 10,
            isWarmup: true
        )
        let addedExercise = Exercise(name: "デッドリフト", primaryBodyPart: .back)
        context.insert(setEntry)
        context.insert(addedExercise)
        try context.save()
        var draft = WorkoutHistoryEditDraft(session: session)
        draft.exercises[0].sets[0].values = SetEntryDraft(weight: "70", reps: "8")
        try draft.addExercise(addedExercise)
        let addedEntryID = try XCTUnwrap(draft.exercises.last?.id)
        draft.addSet(to: addedEntryID)
        draft.exercises[1].sets[0].values = SetEntryDraft(weight: "100", reps: "5")
        let service = WorkoutHistoryEditService(context: context, save: { throw ExpectedError() })

        XCTAssertThrowsError(try service.save(draft, to: session))

        XCTAssertEqual(setEntry.weightKg, 60)
        XCTAssertEqual(setEntry.reps, 10)
        XCTAssertTrue(setEntry.isWarmup)
        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.endedAt, endedAt)
        XCTAssertEqual(draft.exercises[0].sets[0].values, SetEntryDraft(weight: "70", reps: "8"))
        XCTAssertEqual(draft.exercises.count, 2)
        XCTAssertEqual(session.exerciseEntries.map(\.id), [entry.id])
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).map(\.id), [entry.id])
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).map(\.id), [setEntry.id])
    }
}

@MainActor
private struct FailingInsightGenerator: WorkoutInsightGenerating {
    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight {
        throw TestInsightError.failed
    }
}

@MainActor
private struct UnavailableInsightGenerator: WorkoutInsightGenerating {
    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight {
        throw WorkoutInsightGenerationError.unavailable
    }
}

@MainActor
private final class CountingInsightGenerator: WorkoutInsightGenerating {
    private(set) var callCount = 0

    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight {
        callCount += 1
        return GeneratedWorkoutInsight(headline: "未使用", message: "未使用")
    }
}

@MainActor
private struct DelayedInsightGenerator: WorkoutInsightGenerating {
    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight {
        try await Task.sleep(for: .seconds(10))
        return GeneratedWorkoutInsight(headline: "遅延", message: "遅延")
    }
}

private enum TestInsightError: Error {
    case failed
}

@MainActor
private final class CountingMonthlyInsightGenerator: MonthlyInsightGenerating {
    private(set) var callCount = 0

    func generate(from facts: MonthlyInsightFacts) async throws -> GeneratedMonthlyInsight {
        callCount += 1
        return GeneratedMonthlyInsight(message: "\(facts.workoutCount)回")
    }
}

@MainActor
private struct FailingMonthlyInsightGenerator: MonthlyInsightGenerating {
    func generate(from facts: MonthlyInsightFacts) async throws -> GeneratedMonthlyInsight {
        throw TestInsightError.failed
    }
}

@MainActor
private struct UnavailableMonthlyInsightTestGenerator: MonthlyInsightGenerating {
    func generate(from facts: MonthlyInsightFacts) async throws -> GeneratedMonthlyInsight {
        throw MonthlyInsightGenerationError.unavailable
    }
}

@MainActor
private struct DelayedMonthlyInsightGenerator: MonthlyInsightGenerating {
    func generate(from facts: MonthlyInsightFacts) async throws -> GeneratedMonthlyInsight {
        try await Task.sleep(for: .seconds(10))
        return GeneratedMonthlyInsight(message: "古い月")
    }
}

extension KASANETests {
    func testQuickInputResolverMatchesSelectableExerciseOnly() throws {
        let chestPress = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let archived = Exercise(name: "ブルガリアンスクワット", primaryBodyPart: .legs, isArchived: true)
        let generated = GeneratedWorkoutQuickInput(exercises: [
            quickInputExercise(name: "チェストプレス", weight: 30, reps: 10),
            quickInputExercise(name: "ブルガリアンスクワット", weight: 20, reps: 10),
        ])

        let draft = try WorkoutQuickInputResolver().resolve(generated, against: [chestPress, archived])

        XCTAssertEqual(draft.exercises[0].exerciseID, chestPress.id)
        XCTAssertEqual(draft.exercises[0].sets[0].values, SetEntryDraft(weight: "30", reps: "10"))
        XCTAssertNil(draft.exercises[1].exerciseID)
    }

    func testQuickInputDraftUsesSetEntryDraftValidation() {
        XCTAssertNotNil(SetEntryDraft(weight: "30", reps: "10").values(decimalSeparator: "."))
        XCTAssertNil(SetEntryDraft(weight: "30.123", reps: "10").values(decimalSeparator: "."))
        XCTAssertNil(SetEntryDraft(weight: "30", reps: "0").values(decimalSeparator: "."))
    }

    func testQuickInputAvailabilityProvidesActionableReason() {
        XCTAssertEqual(
            WorkoutQuickInputAvailability.appleIntelligenceNotEnabled.unavailableMessage,
            "Apple Intelligenceを有効にするとAI入力を利用できます。"
        )
        XCTAssertEqual(
            WorkoutQuickInputAvailability.modelNotReady.unavailableMessage,
            "Apple Intelligenceを準備中です。しばらくしてから再度お試しください。"
        )
        XCTAssertEqual(
            WorkoutQuickInputAvailability.localeUnsupported.unavailableMessage,
            "現在の言語ではAI入力を利用できません。"
        )
    }

    func testQuickInputAnalysisErrorsProvideClassifiedMessages() {
        XCTAssertEqual(
            WorkoutQuickInputAnalysisError.decodingFailure(debugContext: nil).userMessage,
            "AIの解析結果を読み取れませんでした。もう一度お試しください。"
        )
        XCTAssertEqual(
            WorkoutQuickInputAnalysisError.assetsUnavailable(debugContext: nil).userMessage,
            "Apple Intelligenceを準備中です。しばらくしてから再度お試しください。"
        )
        XCTAssertEqual(
            WorkoutQuickInputAnalysisError.rateLimited(debugContext: nil).userMessage,
            "AIを一時的に利用できません。少し待ってから再度お試しください。"
        )
        XCTAssertEqual(
            WorkoutQuickInputAnalysisError.invalidGeneratedStructure(.invalidOverride).userMessage,
            "AIの解析結果に不整合がありました。もう一度お試しください。"
        )
        XCTAssertEqual(
            WorkoutQuickInputAnalysisError.unknown.userMessage,
            "うまく読み取れませんでした。内容を確認して再度お試しください。"
        )
    }

    func testQuickInputResolverUsesCurrentDecimalSeparatorForReviewDraft() throws {
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let generated = GeneratedWorkoutQuickInput(exercises: [
            quickInputExercise(name: exercise.name, weight: 32.5, reps: 8)
        ])

        let draft = try WorkoutQuickInputResolver(locale: Locale(identifier: "fr_FR"))
            .resolve(generated, against: [exercise])

        XCTAssertEqual(draft.exercises[0].sets[0].values.weight, "32,5")
        XCTAssertNotNil(draft.exercises[0].sets[0].values.values(decimalSeparator: ","))
    }

    func testQuickInputSetExpanderExpandsThreeSets() throws {
        let expanded = try WorkoutQuickInputSetExpander().expand(
            quickInputExercise(name: "チェストプレス", count: 3, weight: 30, reps: 10)
        )

        XCTAssertEqual(expanded.sets, Array(repeating: .init(weightKg: 30, reps: 10), count: 3))
    }

    func testQuickInputSetExpanderAppliesFirstLastAndSpecificOverrides() throws {
        let first = try WorkoutQuickInputSetExpander().expand(
            quickInputExercise(
                name: "チェストプレス",
                count: 3,
                weight: 30,
                reps: 10,
                overrides: [.init(setNumber: 1, weightKg: nil, reps: 12)]
            )
        )
        let last = try WorkoutQuickInputSetExpander().expand(
            quickInputExercise(
                name: "チェストプレス",
                count: 3,
                weight: 30,
                reps: 10,
                overrides: [.init(setNumber: 3, weightKg: nil, reps: 8)]
            )
        )
        let specific = try WorkoutQuickInputSetExpander().expand(
            quickInputExercise(
                name: "チェストプレス",
                count: 3,
                weight: 30,
                reps: 10,
                overrides: [.init(setNumber: 2, weightKg: 32.5, reps: nil)]
            )
        )

        XCTAssertEqual(first.sets.map(\.reps), [12, 10, 10])
        XCTAssertEqual(last.sets.map(\.reps), [10, 10, 8])
        XCTAssertEqual(specific.sets.map(\.weightKg), [30, 32.5, 30])
    }

    func testQuickInputSetExpanderKeepsMissingWeightNil() throws {
        let expanded = try WorkoutQuickInputSetExpander().expand(
            quickInputExercise(name: "チェストプレス", count: 3, weight: nil, reps: 10)
        )

        XCTAssertEqual(expanded.sets.map(\.weightKg), [nil, nil, nil])
    }

    func testQuickInputSetExpanderRejectsInvalidCountAndOverride() {
        XCTAssertThrowsError(
            try WorkoutQuickInputSetExpander().expand(
                quickInputExercise(name: "チェストプレス", count: 0, weight: 30, reps: 10)
            )
        ) { XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .invalidSetCount) }
        let empty = GeneratedWorkoutQuickInputExercise(
            exerciseName: "チェストプレス",
            setPattern: .explicit(.init(sets: []))
        )
        XCTAssertThrowsError(try WorkoutQuickInputSetExpander().expand(empty)) {
            XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .emptySets)
        }
        XCTAssertThrowsError(
            try WorkoutQuickInputSetExpander().expand(
                quickInputExercise(
                    name: "チェストプレス",
                    count: 3,
                    weight: 30,
                    reps: 10,
                    overrides: [.init(setNumber: 5, weightKg: nil, reps: 8)]
                )
            )
        ) { XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .invalidOverride) }
        XCTAssertThrowsError(
            try WorkoutQuickInputSetExpander().expand(
                quickInputExercise(name: "チェストプレス", count: 11, weight: 30, reps: 10)
            )
        ) { XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .tooManySets) }
        XCTAssertThrowsError(
            try WorkoutQuickInputSetExpander().expand(
                quickInputExercise(
                    name: "チェストプレス",
                    count: 3,
                    weight: 30,
                    reps: 10,
                    overrides: [.init(setNumber: 2, weightKg: nil, reps: nil)]
                )
            )
        ) { XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .invalidOverride) }
    }

    func testQuickInputSetExpanderRejectsDuplicateOverrideAndInvalidValues() {
        XCTAssertThrowsError(
            try WorkoutQuickInputSetExpander().expand(
                quickInputExercise(
                    name: "チェストプレス",
                    count: 3,
                    weight: 30,
                    reps: 10,
                    overrides: [
                        .init(setNumber: 2, weightKg: 32.5, reps: nil),
                        .init(setNumber: 2, weightKg: nil, reps: 8),
                    ]
                )
            )
        ) { XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .invalidOverride) }
        for exercise in [
            quickInputExercise(name: "チェストプレス", weight: -1, reps: 10),
            quickInputExercise(name: "チェストプレス", weight: 30, reps: 0),
        ] {
            XCTAssertThrowsError(try WorkoutQuickInputSetExpander().expand(exercise)) {
                XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .invalidSetValue)
            }
        }
    }

    func testQuickInputSetExpanderRejectsTooManyAndInvalidExplicitSets() {
        let tooMany = GeneratedWorkoutQuickInputExercise(
            exerciseName: "チェストプレス",
            setPattern: .explicit(
                .init(sets: Array(repeating: .init(weightKg: 30, reps: 10), count: 11))
            )
        )
        let invalid = GeneratedWorkoutQuickInputExercise(
            exerciseName: "チェストプレス",
            setPattern: .explicit(.init(sets: [.init(weightKg: -1, reps: 0)]))
        )

        XCTAssertThrowsError(try WorkoutQuickInputSetExpander().expand(tooMany)) {
            XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .tooManySets)
        }
        XCTAssertThrowsError(try WorkoutQuickInputSetExpander().expand(invalid)) {
            XCTAssertEqual($0 as? WorkoutQuickInputSetExpansionError, .invalidSetValue)
        }
    }

    func testQuickInputSetExpanderUsesExplicitSetsWithoutExpansion() throws {
        let sets = [
            GeneratedWorkoutQuickInputSet(weightKg: 30, reps: 10),
            GeneratedWorkoutQuickInputSet(weightKg: 32.5, reps: 8),
        ]
        let exercise = GeneratedWorkoutQuickInputExercise(
            exerciseName: "チェストプレス",
            setPattern: .explicit(.init(sets: sets))
        )

        let expanded = try WorkoutQuickInputSetExpander().expand(exercise)

        XCTAssertEqual(expanded.sets, sets)
    }

    func testQuickInputResolverUsesAliasesAndLeavesUnknownUnresolved() throws {
        let latPulldown = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        let hipAbduction = Exercise(name: "ヒップアブダクション", primaryBodyPart: .legs)
        let hipAdduction = Exercise(name: "ヒップアダクション", primaryBodyPart: .legs)
        let generated = GeneratedWorkoutQuickInput(exercises: [
            quickInputExercise(name: "ラットプル", weight: 18, reps: 12),
            quickInputExercise(name: "アブダクション", weight: 20, reps: 10),
            quickInputExercise(name: "アダクション", weight: 20, reps: 10),
            quickInputExercise(name: "未知の種目", weight: 10, reps: 10),
        ])

        let draft = try WorkoutQuickInputResolver().resolve(
            generated,
            against: [latPulldown, hipAbduction, hipAdduction]
        )

        XCTAssertEqual(
            draft.exercises.map(\.exerciseID),
            [
                latPulldown.id, hipAbduction.id, hipAdduction.id, nil,
            ])
    }

    func testQuickInputApplyCreatesOneEntryWithThreeSets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        context.insert(session)
        context.insert(exercise)
        try context.save()
        let draft = quickInputDraft(exerciseID: exercise.id, values: [(30, 10), (30, 10), (30, 8)])

        try WorkoutQuickInputApplyService(context: context).apply(
            draft,
            to: session,
            exercises: [exercise],
            draftStore: WorkoutDraftStore()
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        let sets = try context.fetch(FetchDescriptor<SetEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(sets.map(\.weightKg), [30, 30, 30])
        XCTAssertEqual(sets.map(\.reps), [10, 10, 8])
    }

    func testQuickInputApplyReusesExistingEntryAndAppendsSet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        context.insert(entry)
        context.insert(SetEntry(exerciseEntry: entry, order: 0, weightKg: 30, reps: 10))
        try context.save()

        try WorkoutQuickInputApplyService(context: context).apply(
            quickInputDraft(exerciseID: exercise.id, values: [(32.5, 8)]),
            to: session,
            exercises: [exercise],
            draftStore: WorkoutDraftStore()
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        let sets = try context.fetch(FetchDescriptor<SetEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(sets.map(\.weightKg), [30, 32.5])
        XCTAssertEqual(sets.map(\.reps), [10, 8])
    }

    func testQuickInputApplyMultipleExercisesPreservesInputOrderAtFront() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let existingExercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let existingEntry = ExerciseEntry(workoutSession: session, exercise: existingExercise, order: 0)
        let chest = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let lat = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        context.insert(existingEntry)
        context.insert(chest)
        context.insert(lat)
        try context.save()
        let draft = WorkoutQuickInputDraft(exercises: [
            quickInputDraft(exerciseID: chest.id, values: [(30, 10)]).exercises[0],
            quickInputDraft(exerciseID: lat.id, values: [(18, 12), (18, 12)]).exercises[0],
        ])

        try WorkoutQuickInputApplyService(context: context).apply(
            draft,
            to: session,
            exercises: [existingExercise, chest, lat],
            draftStore: WorkoutDraftStore()
        )

        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>()).sorted { $0.order < $1.order }
        XCTAssertEqual(entries.map(\.exerciseNameSnapshot), ["チェストプレス", "ラットプルダウン", "スクワット"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 3)
    }

    func testQuickInputApplyRollsBackEveryInsertedModelWhenSaveFails() throws {
        struct ExpectedError: Error {}
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        context.insert(session)
        context.insert(exercise)
        try context.save()

        XCTAssertThrowsError(
            try WorkoutQuickInputApplyService(context: context, save: { throw ExpectedError() })
                .apply(
                    quickInputDraft(exerciseID: exercise.id, values: [(30, 10), (30, 8)]),
                    to: session,
                    exercises: [exercise],
                    draftStore: WorkoutDraftStore()
                )
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
    }

    func testQuickInputApplyRejectsPendingDraftWithoutMutation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        context.insert(session)
        context.insert(exercise)
        try context.save()
        let store = WorkoutDraftStore()
        store.updatePending(SetEntryDraft(weight: "30", reps: ""), for: exercise.id, in: session.id)

        XCTAssertThrowsError(
            try WorkoutQuickInputApplyService(context: context).apply(
                quickInputDraft(exerciseID: exercise.id, values: [(32.5, 8)]),
                to: session,
                exercises: [exercise],
                draftStore: store
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutQuickInputApplyError, .pendingDraft("チェストプレス"))
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
    }

    func testQuickInputDraftCanAddEmptySetWithoutChangingExistingSets() {
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let viewModel = WorkoutQuickInputViewModel(parser: FixtureWorkoutQuickInputParser())
        viewModel.draft = quickInputDraft(exerciseID: exercise.id, values: [(30, 10), (32.5, 8)])
        let exerciseDraftID = viewModel.draft?.exercises[0].id

        let setID = exerciseDraftID.flatMap { viewModel.addSet(to: $0) }

        XCTAssertNotNil(setID)
        XCTAssertEqual(viewModel.draft?.exercises.count, 1)
        XCTAssertEqual(viewModel.draft?.exercises[0].sets.count, 3)
        XCTAssertEqual(viewModel.draft?.exercises[0].sets[0].values, SetEntryDraft(weight: "30", reps: "10"))
        XCTAssertEqual(viewModel.draft?.exercises[0].sets[1].values, SetEntryDraft(weight: "32.5", reps: "8"))
        XCTAssertEqual(viewModel.draft?.exercises[0].sets[2].values, SetEntryDraft(weight: "", reps: ""))
    }

    func testQuickInputDraftKeepsExerciseAfterRemovingLastSet() throws {
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let viewModel = WorkoutQuickInputViewModel(parser: FixtureWorkoutQuickInputParser())
        viewModel.draft = quickInputDraft(exerciseID: exercise.id, values: [(30, 10)])
        let exerciseDraft = try XCTUnwrap(viewModel.draft?.exercises[0])

        viewModel.removeSet(id: exerciseDraft.sets[0].id, from: exerciseDraft.id)

        XCTAssertEqual(viewModel.draft?.exercises.count, 1)
        XCTAssertTrue(viewModel.draft?.exercises[0].sets.isEmpty == true)
        XCTAssertEqual(
            viewModel.validationMessage,
            "セットがない種目があります。セットを追加するか、種目を削除してください。"
        )
    }

    func testQuickInputDraftAddsExerciseAndPreventsDuplicateAddOrUpdate() throws {
        let chest = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let row = Exercise(name: "シーテッドロー", primaryBodyPart: .back)
        let deadlift = Exercise(name: "デッドリフト", primaryBodyPart: .fullBody)
        let viewModel = WorkoutQuickInputViewModel(parser: FixtureWorkoutQuickInputParser())
        viewModel.draft = quickInputDraft(exerciseID: chest.id, values: [(30, 10)])

        let rowDraftID = try XCTUnwrap(viewModel.addExercise(row))

        XCTAssertEqual(viewModel.draft?.exercises[1].id, rowDraftID)
        XCTAssertEqual(viewModel.draft?.exercises[1].exerciseID, row.id)
        XCTAssertEqual(viewModel.draft?.exercises[1].sourceName, row.name)
        XCTAssertTrue(viewModel.draft?.exercises[1].sets.isEmpty == true)
        XCTAssertNil(viewModel.addExercise(row))
        XCTAssertFalse(viewModel.updateExercise(draftID: rowDraftID, to: chest))
        XCTAssertEqual(viewModel.draft?.exercises[1].exerciseID, row.id)
        XCTAssertTrue(viewModel.updateExercise(draftID: rowDraftID, to: deadlift))
        XCTAssertEqual(viewModel.draft?.exercises[1].exerciseID, deadlift.id)
        viewModel.removeExercise(id: rowDraftID)
        XCTAssertEqual(viewModel.draft?.exercises.count, 1)
    }

    func testQuickInputDraftValidationUsesSetEntryDraftRules() {
        let exerciseID = UUID()
        let viewModel = WorkoutQuickInputViewModel(parser: FixtureWorkoutQuickInputParser())
        let cases: [(SetEntryDraft, Bool)] = [
            (.init(weight: "", reps: "10"), false),
            (.init(weight: "30", reps: ""), false),
            (.init(weight: "30.123", reps: "10"), false),
            (.init(weight: "30", reps: "0"), false),
            (.init(weight: "30.25", reps: "10"), true),
        ]

        for (values, isValid) in cases {
            viewModel.draft = WorkoutQuickInputDraft(exercises: [
                WorkoutQuickInputExerciseDraft(
                    sourceName: "fixture",
                    exerciseID: exerciseID,
                    sets: [WorkoutQuickInputSetDraft(weight: values.weight, reps: values.reps)]
                )
            ])
            XCTAssertEqual(viewModel.isReviewValid, isValid, "values: \(values)")
        }
        let item = viewModel.draft?.exercises[0]
        if let item { viewModel.draft?.exercises.append(item) }
        XCTAssertFalse(viewModel.isReviewValid)
    }

    func testQuickInputDraftEditingDoesNotChangeSwiftDataUntilApply() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        context.insert(session)
        context.insert(exercise)
        try context.save()
        let viewModel = WorkoutQuickInputViewModel(parser: FixtureWorkoutQuickInputParser())
        viewModel.draft = WorkoutQuickInputDraft(exercises: [])
        let exerciseDraftID = try XCTUnwrap(viewModel.addExercise(exercise))
        _ = viewModel.addSet(to: exerciseDraftID)
        viewModel.draft?.exercises[0].sets[0].values = SetEntryDraft(weight: "30", reps: "10")

        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).isEmpty)

        try WorkoutQuickInputApplyService(context: context).apply(
            try XCTUnwrap(viewModel.draft),
            to: session,
            exercises: [exercise],
            draftStore: WorkoutDraftStore()
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
    }

    private func quickInputExercise(
        name: String,
        count: Int = 1,
        weight: Double?,
        reps: Int?,
        overrides: [GeneratedWorkoutQuickInputOverride] = []
    ) -> GeneratedWorkoutQuickInputExercise {
        GeneratedWorkoutQuickInputExercise(
            exerciseName: name,
            setPattern: .repeated(
                .init(
                    setCount: count,
                    defaultWeightKg: weight,
                    defaultReps: reps,
                    overrides: overrides
                )
            )
        )
    }

    private func quickInputDraft(
        exerciseID: UUID,
        values: [(Double, Int)]
    ) -> WorkoutQuickInputDraft {
        WorkoutQuickInputDraft(exercises: [
            WorkoutQuickInputExerciseDraft(
                sourceName: "fixture",
                exerciseID: exerciseID,
                sets: values.map {
                    WorkoutQuickInputSetDraft(
                        weight: WorkoutSetDisplayFormatter.editableWeightValue($0.0),
                        reps: String($0.1)
                    )
                }
            )
        ])
    }
}

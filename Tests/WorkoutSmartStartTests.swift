import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class WorkoutSmartStartTests: XCTestCase {
    private enum Expected: Error { case save }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentKASANESchema.self)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private func history(_ context: ModelContext, end: TimeInterval = 100) -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: end - 10),
            endedAt: Date(timeIntervalSince1970: end), note: "元のメモ"
        )
        context.insert(session)
        return session
    }

    private func add(
        _ exercise: Exercise, to session: WorkoutSession, in context: ModelContext, order: Int
    ) {
        context.insert(ExerciseEntry(workoutSession: session, exercise: exercise, order: order))
    }

    func testRecentHistoryCountsAndEndDateOrder() throws {
        for count in 0...5 {
            let container = try makeContainer()
            let context = container.mainContext
            var sessions: [WorkoutSession] = []
            let exercise = Exercise(name: "同じ構成", primaryBodyPart: .other)
            context.insert(exercise)
            for index in 0..<count {
                let session = history(context, end: Double(index + 100))
                // 開始日時ではなく終了日時で並ぶことを確認する。
                session.startedAt = Date(timeIntervalSince1970: Double(1000 - index))
                add(exercise, to: session, in: context, order: 0)
                sessions.append(session)
            }
            context.insert(WorkoutSession())
            try context.save()
            let recent = try context.fetch(WorkoutSessionService.recentCompletedDescriptor)
            XCTAssertEqual(recent.map(\.id), Array(sessions.reversed().prefix(3)).map(\.id))
        }
    }

    func testReuseAnyHistoryCopiesOnlyOrderedAvailableExercises() throws {
        for selectedIndex in 0..<3 {
            let container = try makeContainer()
            let context = container.mainContext
            let sessions = (0..<3).map { history(context, end: Double(100 + $0)) }
            let source = sessions[selectedIndex]
            let first = Exercise(name: "最初", primaryBodyPart: .chest)
            let second = Exercise(name: "次", primaryBodyPart: .legs)
            let archived = Exercise(name: "アーカイブ", primaryBodyPart: .other, isArchived: true)
            for exercise in [first, second, archived] { context.insert(exercise) }
            add(second, to: source, in: context, order: 8)
            add(first, to: source, in: context, order: 2)
            add(archived, to: source, in: context, order: 3)
            add(first, to: source, in: context, order: 9)
            let missing = ExerciseEntry(workoutSession: source, exercise: second, order: 5)
            context.insert(missing)
            missing.exercise = nil
            let entry = try XCTUnwrap(source.exerciseEntries.first)
            context.insert(SetEntry(exerciseEntry: entry, order: 0, weightKg: 50, reps: 8))
            try context.save()
            let originalIDs = Set(source.exerciseEntries.map(\.id))
            let startedAt = Date(timeIntervalSince1970: 500)
            let service = WorkoutSessionService(context: context, now: { startedAt })
            let result = try service.startOrResume(reusing: source)
            let entries = result.exerciseEntries.sorted { $0.order < $1.order }
            XCTAssertNotEqual(result.id, source.id)
            XCTAssertEqual(result.startedAt, startedAt)
            XCTAssertNil(result.endedAt)
            XCTAssertNil(result.note)
            XCTAssertEqual(entries.compactMap { $0.exercise?.id }, [first.id, second.id])
            XCTAssertEqual(entries.map(\.order), [0, 1])
            XCTAssertTrue(entries.allSatisfy { $0.setEntries.isEmpty && !originalIDs.contains($0.id) })
            XCTAssertEqual(Set(source.exerciseEntries.map(\.id)), originalIDs)
            XCTAssertEqual(source.note, "元のメモ")
            XCTAssertEqual(source.endedAt, Date(timeIntervalSince1970: Double(100 + selectedIndex)))
            XCTAssertEqual(try context.fetch(FetchDescriptor<SetEntry>()).count, 1)
            XCTAssertEqual(try service.startOrResume(reusing: sessions[0]).id, result.id)
            XCTAssertEqual(try service.startOrResume().id, result.id)
            XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).count, 4)
        }
    }

    func testNoReusableExercisesDoesNotCreateWorkout() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = history(context)
        let archived = Exercise(name: "過去", primaryBodyPart: .other, isArchived: true)
        context.insert(archived)
        add(archived, to: source, in: context, order: 0)
        try context.save()
        XCTAssertThrowsError(try WorkoutSessionService(context: context).startOrResume(reusing: source))
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).count, 1)
        XCTAssertNil(try WorkoutSessionService(context: context).activeSession())
    }

    func testFailedStartRollsBackSessionAndEntriesAndCanRetry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = history(context)
        let exercise = Exercise(name: "種目", primaryBodyPart: .other)
        context.insert(exercise)
        add(exercise, to: source, in: context, order: 0)
        try context.save()
        for sourceToReuse in [source, nil] {
            let failing = WorkoutSessionService(context: context, save: { throw Expected.save })
            XCTAssertThrowsError(try failing.startOrResume(reusing: sourceToReuse))
            XCTAssertNil(try failing.activeSession())
            try context.save()
            let persisted = ModelContext(container)
            XCTAssertEqual(try persisted.fetch(FetchDescriptor<WorkoutSession>()).count, 1)
            XCTAssertEqual(try persisted.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        }
        let result = try WorkoutSessionService(context: context).startOrResume()
        XCTAssertTrue(result.exerciseEntries.isEmpty)
        XCTAssertNil(result.note)
        XCTAssertNil(result.endedAt)
    }

    func testRootGuardsRepeatedTapAndReportsFailure() throws {
        let model = WorkoutRootViewModel()
        model.startWorkout { throw Expected.save }
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.activeSession)
        let session = WorkoutSession()
        var calls = 0
        for _ in 0..<2 {
            model.startWorkout {
                calls += 1
                return session
            }
        }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.activeSession?.id, session.id)
    }
}

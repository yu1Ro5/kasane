import Foundation
import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class WorkoutDateEditTests: XCTestCase {
    private func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    func testStartOnlyEndOnlyAndBothChangesRecalculateDuration() throws {
        for (start, end) in [(200.0, 2_000.0), (100.0, 4_660.0), (1_000.0, 5_560.0)] {
            let container = try makeContainer()
            let context = container.mainContext
            let session = WorkoutSession(
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 2_000)
            )
            context.insert(session)
            try context.save()
            var draft = WorkoutDateEditDraft(session: session)
            draft.startedAt = Date(timeIntervalSince1970: start)
            draft.endedAt = Date(timeIntervalSince1970: end)
            XCTAssertTrue(draft.hasChanges)
            try WorkoutDateEditService(context: context).save(draft, to: session)
            XCTAssertEqual(session.startedAt, draft.startedAt)
            XCTAssertEqual(session.endedAt, draft.endedAt)
            XCTAssertEqual(WorkoutDetailContent(session: session).duration, end - start)
            XCTAssertEqual(WorkoutHistoryRowContent(session: session)?.duration, end - start)
            if end - start == 4_560 { XCTAssertEqual(draft.durationText, "1時間16分") }
        }
    }

    func testDraftCancellationAndInvalidDatesLeaveOriginalUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(session)
        try context.save()
        var draft = WorkoutDateEditDraft(session: session)
        XCTAssertFalse(draft.hasChanges)
        draft.startedAt = Date(timeIntervalSince1970: 300)
        XCTAssertNotNil(draft.validationMessage)
        XCTAssertEqual(draft.durationText, "--")
        XCTAssertEqual(session.startedAt, Date(timeIntervalSince1970: 100))
        XCTAssertThrowsError(try WorkoutDateEditService(context: context).save(draft, to: session))
        XCTAssertEqual(session.endedAt, Date(timeIntervalSince1970: 200))
        let freshDraft = WorkoutDateEditDraft(session: session)
        XCTAssertFalse(freshDraft.hasChanges)
        draft.startedAt = draft.endedAt
        XCTAssertNil(draft.validationMessage)
        try WorkoutDateEditService(context: context).save(draft, to: session)
        XCTAssertEqual(WorkoutDetailContent(session: session).duration, 0)
    }

    func testSaveFailureRestoresDatesAndAllowsRetry() throws {
        enum Failure: Error { case save }
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(session)
        try context.save()
        var draft = WorkoutDateEditDraft(session: session)
        draft.endedAt = Date(timeIntervalSince1970: 300)
        XCTAssertThrowsError(
            try WorkoutDateEditService(context: context, save: { throw Failure.save }).save(draft, to: session)
        )
        XCTAssertTrue(draft.matchesOriginalState(of: session))
        XCTAssertEqual(session.endedAt, Date(timeIntervalSince1970: 200))
        try WorkoutDateEditService(context: context).save(draft, to: session)
        XCTAssertEqual(session.endedAt, draft.endedAt)
    }

    func testActiveAndStaleDraftsAreRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession()
        let service = WorkoutDateEditService(context: context)
        XCTAssertThrowsError(try service.save(WorkoutDateEditDraft(session: session), to: session))
        session.endedAt = session.startedAt
        let draft = WorkoutDateEditDraft(session: session)
        session.endedAt = session.startedAt.addingTimeInterval(60)
        XCTAssertThrowsError(try service.save(draft, to: session))
        let other = WorkoutSession(startedAt: draft.startedAt, endedAt: draft.endedAt)
        XCTAssertThrowsError(try service.save(draft, to: other))
    }

    /// 月をまたぐ編集は開始月の統計と終了日の履歴へ反映し、セット・種目・バックアップを保護する。
    func testCrossMonthEditUpdatesQueriesStatsAndBackupWithoutChangingEntries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let january = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 23))
        )
        let february = january.addingTimeInterval(3_600)
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(
            startedAt: january, endedAt: january.addingTimeInterval(106_080), note: "keep"
        )
        context.insert(session)
        let exercise = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        context.insert(exercise)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 2)
        context.insert(entry)
        let set = SetEntry(exerciseEntry: entry, order: 3, weightKg: 42.5, reps: 8, isWarmup: true)
        context.insert(set)
        try context.save()
        let before = try KASANEBackupExporter(container: container).makeBackup()
        var draft = WorkoutDateEditDraft(session: session)
        draft.startedAt = february.addingTimeInterval(-1_800)
        draft.endedAt = draft.startedAt.addingTimeInterval(4_560)
        try WorkoutDateEditService(context: context).save(draft, to: session)
        XCTAssertEqual(draft.durationText, "1時間16分")
        XCTAssertEqual(WorkoutHistoryRowContent(session: session)?.completedAt, draft.endedAt)
        XCTAssertEqual(
            try OverviewWorkoutLoader.fetchMonthlyWorkouts(
                containing: january, calendar: calendar, in: context
            ).map(\.id),
            [session.id]
        )
        draft = WorkoutDateEditDraft(session: session)
        draft.startedAt = february
        try WorkoutDateEditService(context: context).save(draft, to: session)
        XCTAssertTrue(
            try OverviewWorkoutLoader.fetchMonthlyWorkouts(
                containing: january, calendar: calendar, in: context
            ).isEmpty
        )
        let monthly = try OverviewWorkoutLoader.fetchMonthlyWorkouts(
            containing: february, calendar: calendar, in: context
        )
        XCTAssertEqual(monthly.map(\.id), [session.id])
        let stats = OverviewStats(sessions: monthly, now: february, calendar: calendar)
        XCTAssertEqual(stats.duration, 2_760)
        XCTAssertEqual(stats.dailyWorkoutCounts, [calendar.startOfDay(for: february): 1])
        XCTAssertEqual(try OverviewWorkoutLoader.fetchRecentWorkouts(in: context).map(\.id), [session.id])
        XCTAssertEqual(
            ExerciseProgressBuilder.build(exerciseID: exercise.id, entries: [entry])?.points.first?.completedAt,
            draft.endedAt
        )
        XCTAssertEqual(ExerciseOverviewCardBuilder.build(entries: [entry]).first?.latestCompletedAt, draft.endedAt)
        let after = try KASANEBackupExporter(container: container).makeBackup()
        XCTAssertEqual(after.workouts.first?.exerciseEntries, before.workouts.first?.exerciseEntries)
        XCTAssertEqual(after.workouts.first?.note, "keep")
        XCTAssertEqual(after.workouts.first?.startedAt, draft.startedAt)
        XCTAssertEqual(after.workouts.first?.endedAt, draft.endedAt)
        let destination = try makeContainer()
        let decoded = try KASANEBackupCoding.decode(KASANEBackupCoding.encode(after))
        try KASANEBackupImporter(container: destination).importBackup(decoded)
        let restored = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(restored.startedAt, draft.startedAt)
        XCTAssertEqual(restored.endedAt, draft.endedAt)
        XCTAssertEqual(restored.exerciseEntries.first?.setEntries.first?.weightKg, 42.5)
    }

    /// 既存形式のファイルストアを閉じて開き直しても、編集値と未編集Workoutを読み込める。
    func testEditedDatesPersistAfterReopeningExistingStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("workouts.store")
        let editedID = UUID()
        let originalStart = Date(timeIntervalSince1970: 100)
        let originalEnd = Date(timeIntervalSince1970: 106_180)
        do {
            let container = try makeContainer(url: url)
            container.mainContext.insert(
                WorkoutSession(id: editedID, startedAt: originalStart, endedAt: originalEnd)
            )
            container.mainContext.insert(WorkoutSession(startedAt: originalStart, endedAt: originalEnd))
            try container.mainContext.save()
        }
        do {
            let container = try makeContainer(url: url)
            let session = try XCTUnwrap(
                container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == editedID }
            )
            var draft = WorkoutDateEditDraft(session: session)
            draft.endedAt = originalStart.addingTimeInterval(4_560)
            try WorkoutDateEditService(context: container.mainContext).save(draft, to: session)
        }
        let reopened = try makeContainer(url: url)
        let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 2)
        let edited = try XCTUnwrap(sessions.first { $0.id == editedID })
        XCTAssertEqual(WorkoutDetailContent(session: edited).durationText, "1時間16分")
        let untouched = try XCTUnwrap(sessions.first { $0.id != editedID })
        XCTAssertEqual(untouched.startedAt, originalStart)
        XCTAssertEqual(untouched.endedAt, originalEnd)
    }
}

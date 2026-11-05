import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class ExerciseFormTests: XCTestCase {
    private func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Exercise.self, WorkoutSession.self, ExerciseEntry.self, SetEntry.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    func testSaveTrimsNameAndCreatesOnlyExercise() throws {
        let container = try makeContainer()
        let draft = ExerciseFormViewModel(name: "  ジムのマシン \n", bodyPart: .back)
        XCTAssertTrue(draft.save(in: container))
        let exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.name), ["ジムのマシン"])
        XCTAssertEqual(exercises.first?.bodyPart, .back)
        XCTAssertTrue(exercises.first?.isSelectable == true)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ExerciseEntry>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SetEntry>()), 0)
    }

    func testInvalidAndDuplicateNamesDoNotSave() throws {
        let container = try makeContainer()
        XCTAssertTrue(ExerciseFormViewModel(name: "Machine").save(in: container))
        for name in ["", " \n　", String(repeating: "あ", count: 81), " machine ", "Ｍａｃｈｉｎｅ"] {
            let draft = ExerciseFormViewModel(name: name)
            XCTAssertFalse(draft.save(in: container), name)
            XCTAssertNotNil(draft.errorMessage)
        }
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Exercise>()), 1)
    }

    func testSaveFailureKeepsDraftAndAllowsRetry() throws {
        let container = try makeContainer()
        let draft = ExerciseFormViewModel(name: "入力した種目", bodyPart: .legs)
        XCTAssertFalse(draft.save(in: container) { _ in throw CocoaError(.fileWriteUnknown) })
        XCTAssertEqual(draft.name, "入力した種目")
        XCTAssertEqual(draft.bodyPart, .legs)
        XCTAssertNotNil(draft.errorMessage)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Exercise>()), 0)
        XCTAssertTrue(draft.save(in: container))
        XCTAssertNil(draft.errorMessage)
    }

    func testAbandoningDraftDoesNotSave() throws {
        let container = try makeContainer()
        let draft = ExerciseFormViewModel()
        XCTAssertFalse(draft.hasChanges)
        draft.name = "保存しない種目"
        XCTAssertTrue(draft.hasChanges)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Exercise>()), 0)
    }

    func testSeedPreservesCustomAndModifiedArchivedBuiltIn() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try ExerciseCatalogService(context: context).seed()
        let first = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first)
        first.name = "変更済み"
        first.isArchived = true
        try context.save()
        XCTAssertTrue(ExerciseFormViewModel(name: "独自種目").save(in: container))
        try ExerciseCatalogService(context: context).seed()
        try ExerciseCatalogService(context: context).seed()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), ExerciseCatalogService.builtIns.count + 1)
        XCTAssertEqual(first.name, "変更済み")
        XCTAssertTrue(first.isArchived)
    }

    func testCustomExerciseSurvivesReopeningStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        var id: UUID?
        do {
            let container = try makeContainer(url: url)
            XCTAssertTrue(ExerciseFormViewModel(name: "永続化種目", bodyPart: .arms).save(in: container))
            id = try container.mainContext.fetch(FetchDescriptor<Exercise>()).first?.id
        }
        let reopened = try makeContainer(url: url)
        let exercise = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Exercise>()).first)
        XCTAssertEqual(exercise.id, id)
        XCTAssertEqual(exercise.name, "永続化種目")
        XCTAssertEqual(exercise.bodyPart, .arms)
    }

    func testCustomExerciseAndWorkoutSurviveBackupRestoreAndSeed() throws {
        let source = try makeContainer()
        XCTAssertTrue(ExerciseFormViewModel(name: "独自のプレス", bodyPart: .chest).save(in: source))
        XCTAssertTrue(ExerciseFormViewModel(name: "未記録種目", bodyPart: .core).save(in: source))
        let context = source.mainContext
        let exercise = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first(where: { $0.name == "独自のプレス" }))
        let session = WorkoutSession(startedAt: Date(), endedAt: Date())
        context.insert(session)
        try context.save()
        _ = try WorkoutExerciseService(context: context).recordFirstSet(
            draft: SetEntryDraft(weight: "42.5", reps: "8"), for: exercise, in: session)
        let backup = try KASANEBackupExporter(container: source).makeBackup()
        let destination = try makeContainer()
        try KASANEBackupImporter(container: destination).importBackup(backup)
        try ExerciseCatalogService(context: destination.mainContext).seed()
        let restored = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<ExerciseEntry>()).first)
        XCTAssertEqual(restored.exercise?.id, exercise.id)
        XCTAssertEqual(restored.exerciseNameSnapshot, "独自のプレス")
        XCTAssertEqual(restored.setEntries.first?.weightKg, 42.5)
        XCTAssertEqual(restored.setEntries.first?.reps, 8)
        XCTAssertEqual(
            try destination.mainContext.fetchCount(FetchDescriptor<Exercise>()),
            ExerciseCatalogService.builtIns.count + 2)
        let restoredWorkout = try XCTUnwrap(restored.workoutSession)
        let replay = ReplayStatsBuilder.build(
            year: Calendar.current.component(.year, from: session.startedAt), workouts: [restoredWorkout])
        XCTAssertEqual(replay.totalVolume, 340)
        XCTAssertEqual(replay.mostTrained?.exerciseID, exercise.id)
        XCTAssertTrue(
            WorkoutSessionService.reusableExercises(from: restoredWorkout).contains(where: { $0.id == exercise.id }))
    }
}

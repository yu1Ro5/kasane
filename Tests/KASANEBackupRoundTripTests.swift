import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class KASANEBackupRoundTripTests: XCTestCase {
    func testExportImportExportPreservesAllValuesRelationshipsAndNilExercise() throws {
        let source = try makeContainer()
        let context = source.mainContext
        let exercise = Exercise(
            id: BackupTestFixture.exerciseID, name: "ベンチプレス", primaryBodyPart: .chest, isArchived: true)
        context.insert(exercise)
        let workout = WorkoutSession(
            id: BackupTestFixture.workoutID, startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200), note: "note")
        context.insert(workout)
        let entry = ExerciseEntry(id: BackupTestFixture.entryID, workoutSession: workout, exercise: exercise, order: 2)
        entry.exerciseNameSnapshot = "snapshot name"
        entry.primaryBodyPartSnapshot = "unknown-future-value"
        context.insert(entry)
        context.insert(
            SetEntry(
                id: BackupTestFixture.setID, exerciseEntry: entry, order: 4, weightKg: 12.5, reps: 9, isWarmup: true))
        let nilEntry = ExerciseEntry(workoutSession: workout, exercise: exercise, order: 5)
        nilEntry.exercise = nil
        nilEntry.exerciseNameSnapshot = "削除済み種目"
        nilEntry.primaryBodyPartSnapshot = "legacy"
        context.insert(nilEntry)
        let ongoing = WorkoutSession(startedAt: Date(timeIntervalSince1970: 300))
        context.insert(ongoing)
        try context.save()

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try KASANEBackupExporter(container: source).makeBackup(now: fixedDate)
        XCTAssertNil(first.workouts.first?.exerciseEntries.last?.exerciseID)
        let data = try KASANEBackupCoding.encode(first)
        let decoded = try KASANEBackupCoding.decode(data)
        try KASANEBackupValidator.validate(decoded)

        let destination = try makeContainer()
        try KASANEBackupImporter(container: destination).importBackup(decoded)
        let second = try KASANEBackupExporter(container: destination).makeBackup(now: fixedDate)
        XCTAssertEqual(second, first)
    }

    func testExportIsReadOnlyAndSortsEveryCollection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let later = Exercise(
            id: UUID(uuidString: "FFFFFFFF-FFFF-4FFF-8FFF-FFFFFFFFFFFF") ?? UUID(), name: "later",
            primaryBodyPart: .other)
        let earlier = Exercise(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000000") ?? UUID(), name: "earlier",
            primaryBodyPart: .other)
        context.insert(later)
        context.insert(earlier)
        let workout = WorkoutSession(startedAt: Date(), endedAt: Date())
        context.insert(workout)
        let high = ExerciseEntry(workoutSession: workout, exercise: later, order: 3)
        let low = ExerciseEntry(workoutSession: workout, exercise: earlier, order: 1)
        context.insert(high)
        context.insert(low)
        context.insert(SetEntry(exerciseEntry: low, order: 2, weightKg: 1, reps: 1))
        context.insert(SetEntry(exerciseEntry: low, order: 0, weightKg: 1, reps: 1))
        try context.save()

        let before = try context.fetchCount(FetchDescriptor<ExerciseEntry>())
        let backup = try KASANEBackupExporter(container: container).makeBackup()
        XCTAssertEqual(backup.exercises.map(\.name), ["earlier", "later"])
        XCTAssertEqual(backup.workouts[0].exerciseEntries.map(\.order), [1, 3])
        XCTAssertEqual(backup.workouts[0].exerciseEntries[0].sets.map(\.order), [0, 2])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseEntry>()), before)
        XCTAssertFalse(context.hasChanges)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self])
        return try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
}

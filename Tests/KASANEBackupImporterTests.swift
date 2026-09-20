import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class KASANEBackupImporterTests: XCTestCase {
    func testImportReplacesExistingData() throws {
        let container = try makeContainer()
        let oldExercise = Exercise(name: "old", primaryBodyPart: .other)
        container.mainContext.insert(oldExercise)
        container.mainContext.insert(WorkoutSession(startedAt: Date(), endedAt: Date()))
        try container.mainContext.save()

        try KASANEBackupImporter(container: container).importBackup(BackupTestFixture.backup())

        let exercises = try ModelContext(container).fetch(FetchDescriptor<Exercise>())
        let workouts = try ModelContext(container).fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(exercises.map(\.id), [BackupTestFixture.exerciseID])
        XCTAssertEqual(workouts.map(\.id), [BackupTestFixture.workoutID])
    }

    func testValidationFailureDoesNotStartTransactionOrChangeData() throws {
        let container = try containerWithExistingData()
        var transactionReached = false
        let importer = KASANEBackupImporter(container: container) { _ in transactionReached = true }

        XCTAssertThrowsError(try importer.importBackup(BackupTestFixture.backup(formatVersion: 2)))
        XCTAssertFalse(transactionReached)
        try assertExistingDataRemains(in: container)
    }

    func testTransactionFailureRollsBackDeletionAndInsertions() throws {
        enum Injected: Error { case failure }
        let container = try containerWithExistingData()
        let importer = KASANEBackupImporter(container: container) { _ in throw Injected.failure }

        XCTAssertThrowsError(try importer.importBackup(BackupTestFixture.backup()))
        try assertExistingDataRemains(in: container)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 1)
        XCTAssertFalse(
            try context.fetch(FetchDescriptor<WorkoutSession>()).contains {
                $0.id == BackupTestFixture.workoutID
            })
        XCTAssertFalse(
            try context.fetch(FetchDescriptor<Exercise>()).contains {
                $0.id == BackupTestFixture.exerciseID
            })
    }

    func testOngoingWorkoutRejectsImportBeforeTransaction() throws {
        let container = try makeContainer()
        container.mainContext.insert(WorkoutSession(startedAt: Date()))
        try container.mainContext.save()
        var transactionReached = false
        let importer = KASANEBackupImporter(container: container) { _ in transactionReached = true }

        XCTAssertThrowsError(try importer.importBackup(BackupTestFixture.backup())) { error in
            XCTAssertTrue(error is KASANEBackupImportError)
        }
        XCTAssertFalse(transactionReached)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<WorkoutSession>()), 1)
    }

    private func containerWithExistingData() throws -> ModelContainer {
        let container = try makeContainer()
        container.mainContext.insert(Exercise(name: "existing", primaryBodyPart: .other))
        container.mainContext.insert(WorkoutSession(startedAt: Date(), endedAt: Date()))
        try container.mainContext.save()
        return container
    }

    private func assertExistingDataRemains(in container: ModelContainer) throws {
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).map(\.name), ["existing"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self])
        return try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
}

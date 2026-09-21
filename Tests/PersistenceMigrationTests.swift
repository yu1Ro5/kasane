import Foundation
import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class PersistenceMigrationTests: XCTestCase {
    func testV1IdentityContainsOnlyProductionModels() {
        XCTAssertEqual(KASANESchemaV1.versionIdentifier, .init(1, 0, 0))
        XCTAssertEqual(KASANESchemaV1.models.count, 4)
        XCTAssertEqual(
            Set(KASANESchemaV1.models.map { String(describing: $0) }),
            Set(["WorkoutSession", "Exercise", "ExerciseEntry", "SetEntry"])
        )
        XCTAssertTrue(KASANEMigrationPlan.stages.isEmpty)
    }

    func testNonVersionedDiskStoreOpensAsV1WithoutLosingValuesOrRelationships() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("legacy.store")
        let legacySchema = Schema([
            WorkoutSession.self,
            Exercise.self,
            ExerciseEntry.self,
            SetEntry.self,
        ])
        let legacyConfiguration = ModelConfiguration(schema: legacySchema, url: storeURL)

        let sessionID = try XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
        let exerciseID = try XCTUnwrap(UUID(uuidString: "20000000-0000-4000-8000-000000000001"))
        let entryID = try XCTUnwrap(UUID(uuidString: "30000000-0000-4000-8000-000000000001"))
        let setID = try XCTUnwrap(UUID(uuidString: "40000000-0000-4000-8000-000000000001"))
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endedAt = Date(timeIntervalSince1970: 1_700_003_600)

        do {
            let legacyContainer = try ModelContainer(
                for: legacySchema,
                configurations: legacyConfiguration
            )
            let context = legacyContainer.mainContext
            let session = WorkoutSession(
                id: sessionID,
                startedAt: startedAt,
                endedAt: endedAt,
                note: "legacy note"
            )
            let exercise = Exercise(
                id: exerciseID,
                name: "Legacy Press",
                primaryBodyPart: .chest,
                isArchived: true
            )
            let entry = ExerciseEntry(
                id: entryID,
                workoutSession: session,
                exercise: exercise,
                order: 2
            )
            entry.exerciseNameSnapshot = "Snapshot Press"
            entry.primaryBodyPartSnapshot = "snapshot-body-part"
            let set = SetEntry(
                id: setID,
                exerciseEntry: entry,
                order: 3,
                weightKg: 82.5,
                reps: 7,
                isWarmup: true
            )
            context.insert(session)
            context.insert(exercise)
            context.insert(entry)
            context.insert(set)
            try context.save()
        }

        let v1Schema = Schema(versionedSchema: KASANESchemaV1.self)
        let container = try ModelContainer(
            for: v1Schema,
            migrationPlan: KASANEMigrationPlan.self,
            configurations: ModelConfiguration(schema: v1Schema, url: storeURL)
        )
        let sessions = try container.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.id, sessionID)
        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.endedAt, endedAt)
        XCTAssertEqual(session.note, "legacy note")
        let entry = try XCTUnwrap(session.exerciseEntries.first)
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.exerciseNameSnapshot, "Snapshot Press")
        XCTAssertEqual(entry.primaryBodyPartSnapshot, "snapshot-body-part")
        XCTAssertEqual(entry.order, 2)
        XCTAssertIdentical(entry.workoutSession, session)
        let exercise = try XCTUnwrap(entry.exercise)
        XCTAssertEqual(exercise.id, exerciseID)
        XCTAssertEqual(exercise.name, "Legacy Press")
        XCTAssertEqual(exercise.primaryBodyPart, BodyPart.chest.rawValue)
        XCTAssertTrue(exercise.isArchived)
        XCTAssertEqual(exercise.exerciseEntries.map(\.id), [entryID])
        let set = try XCTUnwrap(entry.setEntries.first)
        XCTAssertEqual(set.id, setID)
        XCTAssertEqual(set.order, 3)
        XCTAssertEqual(set.weightKg, 82.5)
        XCTAssertEqual(set.reps, 7)
        XCTAssertTrue(set.isWarmup)
        XCTAssertIdentical(set.exerciseEntry, entry)
    }

    func testExerciseCatalogSeedRollsBackAndCanRetryAfterSaveFailure() throws {
        let schema = Schema(versionedSchema: CurrentKASANESchema.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        enum Expected: Error { case save }
        let failing = ExerciseCatalogService(context: container.mainContext) { throw Expected.save }
        XCTAssertThrowsError(try failing.seed())
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Exercise>()).isEmpty)

        try ExerciseCatalogService(context: container.mainContext).seed()
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<Exercise>()).count,
            ExerciseCatalogService.builtIns.count
        )
        try ExerciseCatalogService(context: container.mainContext).seed()
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<Exercise>()).count,
            ExerciseCatalogService.builtIns.count
        )
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

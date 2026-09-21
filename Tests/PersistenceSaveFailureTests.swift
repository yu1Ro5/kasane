import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class PersistenceSaveFailureTests: XCTestCase {
    private enum Expected: Error { case save }

    func testWorkoutSetAddFailureKeepsPersistedState() throws {
        let fixture = try makeFixture()
        let service = WorkoutSetService(context: fixture.context) { throw Expected.save }
        XCTAssertThrowsError(
            try service.add(
                draft: SetEntryDraft(weight: "20", reps: "8"),
                to: fixture.entry
            )
        )
        let persistedContext = ModelContext(fixture.container)
        XCTAssertEqual(try persistedContext.fetch(FetchDescriptor<SetEntry>()).count, 1)
    }

    func testWorkoutSetUpdateFailureKeepsPersistedState() throws {
        let fixture = try makeFixture()
        let service = WorkoutSetService(context: fixture.context) { throw Expected.save }
        XCTAssertThrowsError(
            try service.update(
                fixture.set,
                draft: SetEntryDraft(weight: "99", reps: "3")
            )
        )
        let persisted = try XCTUnwrap(
            ModelContext(fixture.container).fetch(FetchDescriptor<SetEntry>()).first
        )
        XCTAssertEqual(persisted.weightKg, 10)
        XCTAssertEqual(persisted.reps, 5)
    }

    func testWorkoutSetDeleteFailureKeepsPersistedState() throws {
        let fixture = try makeFixture()
        let service = WorkoutSetService(context: fixture.context) { throw Expected.save }
        XCTAssertThrowsError(try service.delete(fixture.set, from: fixture.entry))
        XCTAssertEqual(
            try ModelContext(fixture.container).fetch(FetchDescriptor<SetEntry>()).map(\.id),
            [fixture.set.id]
        )
    }

    func testWorkoutExerciseRecordFirstSetFailureKeepsPersistedState() throws {
        let fixture = try makeFixture(includeEntry: false)
        let service = WorkoutExerciseService(context: fixture.context) { throw Expected.save }
        XCTAssertThrowsError(
            try service.recordFirstSet(
                draft: SetEntryDraft(weight: "20", reps: "8"),
                for: fixture.exercise,
                in: fixture.session
            )
        )
        let persistedContext = ModelContext(fixture.container)
        XCTAssertTrue(try persistedContext.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try persistedContext.fetch(FetchDescriptor<SetEntry>()).isEmpty)
    }

    func testWorkoutExerciseDeleteFailureKeepsPersistedState() throws {
        let fixture = try makeFixture()
        let service = WorkoutExerciseService(context: fixture.context) { throw Expected.save }
        XCTAssertThrowsError(try service.delete(fixture.entry, from: fixture.session))
        XCTAssertEqual(
            try ModelContext(fixture.container).fetch(FetchDescriptor<ExerciseEntry>()).map(\.id),
            [fixture.entry.id]
        )
        XCTAssertEqual(
            try ModelContext(fixture.container).fetch(FetchDescriptor<SetEntry>()).map(\.id),
            [fixture.set.id]
        )
    }

    private func makeFixture(includeEntry: Bool = true) throws -> Fixture {
        let schema = Schema(versionedSchema: CurrentKASANESchema.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let session = WorkoutSession()
        let exercise = Exercise(name: "テスト", primaryBodyPart: .other)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        let set = SetEntry(exerciseEntry: entry, order: 0, weightKg: 10, reps: 5)
        context.insert(session)
        context.insert(exercise)
        if includeEntry {
            context.insert(entry)
            context.insert(set)
        }
        try context.save()
        return Fixture(
            container: container,
            context: context,
            session: session,
            exercise: exercise,
            entry: entry,
            set: set
        )
    }

    private struct Fixture {
        // ModelContainerをテスト終了まで保持する。
        let container: ModelContainer
        let context: ModelContext
        let session: WorkoutSession
        let exercise: Exercise
        let entry: ExerciseEntry
        let set: SetEntry
    }
}

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
}

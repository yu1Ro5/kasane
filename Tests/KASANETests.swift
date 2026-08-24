import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class KASANETests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutExercise.self,
            WorkoutSet.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    func testWorkoutCanBeSavedAndFetched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workout = Workout(startedAt: Date(timeIntervalSince1970: 100), note: "Morning")

        context.insert(workout)
        try context.save()

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.id, workout.id)
        XCTAssertEqual(workouts.first?.note, "Morning")
    }

    func testWorkoutGraphCanBeSavedAndFetched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workout = Workout()
        let exercise = Exercise(name: "Bench Press", primaryBodyPart: .chest)
        let workoutExercise = WorkoutExercise(workout: workout, exercise: exercise, order: 0)
        let set = WorkoutSet(
            workoutExercise: workoutExercise,
            order: 0,
            weightKg: 80,
            reps: 8
        )
        workout.exercises.append(workoutExercise)
        workoutExercise.sets.append(set)

        context.insert(workout)
        context.insert(exercise)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Workout>()).first)
        XCTAssertEqual(fetched.exercises.first?.exercise?.id, exercise.id)
        XCTAssertEqual(fetched.exercises.first?.sets.first?.weightKg, 80)
    }

    func testExerciseCanBeReferencedByMultipleWorkouts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Squat", primaryBodyPart: .legs)
        let first = WorkoutExercise(workout: Workout(), exercise: exercise, order: 0)
        let second = WorkoutExercise(workout: Workout(), exercise: exercise, order: 0)

        context.insert(first)
        context.insert(second)
        try context.save()

        XCTAssertEqual(exercise.workoutExercises.count, 2)
    }

    func testDeletingWorkoutCascadesThroughItsGraph() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workout = Workout()
        let exercise = Exercise(name: "Deadlift", primaryBodyPart: .back)
        let workoutExercise = WorkoutExercise(workout: workout, exercise: exercise, order: 0)
        workout.exercises.append(workoutExercise)
        workoutExercise.sets.append(
            WorkoutSet(workoutExercise: workoutExercise, order: 0, weightKg: 120, reps: 5)
        )
        context.insert(workout)
        context.insert(exercise)
        try context.save()

        context.delete(workout)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutExercise>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutSet>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
    }

    func testArchivingAndRenamingExercisePreservesWorkoutSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Press", primaryBodyPart: .shoulders)
        let workoutExercise = WorkoutExercise(workout: Workout(), exercise: exercise, order: 0)
        context.insert(workoutExercise)
        try context.save()

        exercise.name = "Overhead Press"
        exercise.bodyPart = .arms
        exercise.isArchived = true
        try context.save()

        XCTAssertTrue(exercise.isArchived)
        XCTAssertEqual(workoutExercise.exerciseNameSnapshot, "Press")
        XCTAssertEqual(workoutExercise.bodyPartSnapshot, .shoulders)
        XCTAssertEqual(workoutExercise.exercise?.id, exercise.id)
    }
}

import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    @Attribute(.unique) var id: UUID
    var exerciseNameSnapshot: String
    var primaryBodyPartSnapshot: String
    var order: Int
    var workout: Workout?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise)
    var sets: [WorkoutSet]

    init(
        id: UUID = UUID(),
        workout: Workout,
        exercise: Exercise,
        order: Int
    ) {
        self.id = id
        self.workout = workout
        self.exercise = exercise
        exerciseNameSnapshot = exercise.name
        primaryBodyPartSnapshot = exercise.primaryBodyPart
        self.order = order
        sets = []
    }

    var bodyPartSnapshot: BodyPart {
        BodyPart(rawValue: primaryBodyPartSnapshot) ?? .other
    }
}

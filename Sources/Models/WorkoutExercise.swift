import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    /// ワークアウト種目ID
    @Attribute(.unique) var id: UUID
    /// 種目名スナップショット
    var exerciseNameSnapshot: String
    /// 主対象部位スナップショット
    var primaryBodyPartSnapshot: String
    /// 種目順
    var order: Int
    /// ワークアウト
    var workout: Workout?
    /// 種目
    var exercise: Exercise?

    /// セット
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

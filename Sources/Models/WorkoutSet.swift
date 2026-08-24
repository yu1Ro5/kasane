import Foundation
import SwiftData

@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var order: Int
    var weightKg: Double
    var reps: Int
    var isWarmup: Bool
    var workoutExercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        workoutExercise: WorkoutExercise,
        order: Int,
        weightKg: Double,
        reps: Int,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.workoutExercise = workoutExercise
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.isWarmup = isWarmup
    }
}

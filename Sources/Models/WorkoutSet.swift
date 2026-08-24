import Foundation
import SwiftData

@Model
final class WorkoutSet {
    /// セットID
    @Attribute(.unique) var id: UUID
    /// セット順
    var order: Int
    /// 重量kg
    var weightKg: Double
    /// 回数
    var reps: Int
    /// ウォームアップフラグ
    var isWarmup: Bool
    /// ワークアウト種目
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

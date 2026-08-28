import Foundation
import SwiftData

@Model
final class SetEntry {
    /// セット記録ID
    @Attribute(.unique) var id: UUID
    /// セット順
    var order: Int
    /// 重量kg
    var weightKg: Double
    /// 回数
    var reps: Int
    /// ウォームアップフラグ
    var isWarmup: Bool
    /// 種目実施記録
    var exerciseEntry: ExerciseEntry?

    init(
        id: UUID = UUID(),
        exerciseEntry: ExerciseEntry?,
        order: Int,
        weightKg: Double,
        reps: Int,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.exerciseEntry = exerciseEntry
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.isWarmup = isWarmup
    }
}

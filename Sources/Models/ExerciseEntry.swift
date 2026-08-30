import Foundation
import SwiftData

@Model
final class ExerciseEntry {
    /// 種目実施記録ID
    @Attribute(.unique) var id: UUID
    /// 種目名スナップショット
    var exerciseNameSnapshot: String
    /// 主対象部位スナップショット
    var primaryBodyPartSnapshot: String
    /// 種目順
    var order: Int
    /// ワークアウトセッション
    var workoutSession: WorkoutSession?
    /// 種目
    var exercise: Exercise?

    /// セット一覧
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exerciseEntry)
    var setEntries: [SetEntry]

    init(
        id: UUID = UUID(),
        workoutSession: WorkoutSession,
        exercise: Exercise,
        order: Int
    ) {
        self.id = id
        self.workoutSession = workoutSession
        self.exercise = exercise
        exerciseNameSnapshot = exercise.name
        primaryBodyPartSnapshot = exercise.primaryBodyPart
        self.order = order
        setEntries = []
    }

    var bodyPartSnapshot: BodyPart {
        BodyPart(rawValue: primaryBodyPartSnapshot) ?? .other
    }
}

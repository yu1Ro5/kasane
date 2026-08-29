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

    /// 入力途中の未確定Draft。両方が空の場合はnilとして保持する。
    var draftWeight: String?
    var draftReps: String?

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
        draftWeight = nil
        draftReps = nil
    }

    var bodyPartSnapshot: BodyPart {
        BodyPart(rawValue: primaryBodyPartSnapshot) ?? .other
    }
}

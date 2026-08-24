import Foundation
import SwiftData

@Model
final class Workout {
    /// ワークアウトID
    @Attribute(.unique) var id: UUID
    /// 開始日時
    var startedAt: Date
    /// 終了日時
    var endedAt: Date?
    /// ワークアウトメモ
    var note: String?

    /// ワークアウト種目
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        exercises = []
    }
}

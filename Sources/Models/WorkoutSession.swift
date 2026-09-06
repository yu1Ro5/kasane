import Foundation
import SwiftData

@Model
final class WorkoutSession {
    /// ワークアウトセッションID
    @Attribute(.unique) var id: UUID
    /// 開始日時
    var startedAt: Date
    /// 終了日時
    var endedAt: Date?
    /// ワークアウトメモ
    var note: String?

    /// 実施種目一覧
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workoutSession)
    var exerciseEntries: [ExerciseEntry]

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
        exerciseEntries = []
    }
}

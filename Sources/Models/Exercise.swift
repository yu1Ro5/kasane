import Foundation
import SwiftData

@Model
final class Exercise {
    /// 種目ID
    @Attribute(.unique) var id: UUID
    /// 種目名
    var name: String
    /// 主対象部位
    var primaryBodyPart: String
    /// アーカイブフラグ
    var isArchived: Bool

    /// この種目を参照するワークアウト種目
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutExercises: [WorkoutExercise]

    init(
        id: UUID = UUID(),
        name: String,
        primaryBodyPart: BodyPart,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.primaryBodyPart = primaryBodyPart.rawValue
        self.isArchived = isArchived
        workoutExercises = []
    }

    var bodyPart: BodyPart {
        get { BodyPart(rawValue: primaryBodyPart) ?? .other }
        set { primaryBodyPart = newValue.rawValue }
    }
}

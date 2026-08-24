import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var primaryBodyPart: String
    var isArchived: Bool

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

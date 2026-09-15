import Foundation
import FoundationModels

@Generable
struct GeneratedWorkoutQuickInput: Equatable {
    @Guide(description: "ユーザーが記録した種目。入力に現れた順。", .maximumCount(8))
    var exercises: [GeneratedWorkoutQuickInputExercise]
}

@Generable
struct GeneratedWorkoutQuickInputExercise: Equatable {
    @Guide(description: "筋力トレーニングの種目名。利用可能な種目名に明確に対応する場合はその正式名称。")
    var exerciseName: String

    @Guide(description: "この種目で実施したセット。実施順。", .maximumCount(10))
    var sets: [GeneratedWorkoutQuickInputSet]
}

@Generable
struct GeneratedWorkoutQuickInputSet: Equatable {
    @Guide(description: "ユーザーが明示した重量kg。重量が書かれていなければnil。")
    var weightKg: Double?

    @Guide(description: "ユーザーが明示した回数。回数が書かれていなければnil。")
    var reps: Int?
}

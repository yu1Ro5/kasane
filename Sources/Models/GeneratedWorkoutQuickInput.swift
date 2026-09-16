import Foundation
import FoundationModels

@Generable
struct GeneratedWorkoutQuickInput: Equatable {
    @Guide(description: "ユーザーが記録した種目。入力に現れた順。", .maximumCount(8))
    var exercises: [GeneratedWorkoutQuickInputExercise]
}

@Generable
struct GeneratedWorkoutQuickInputExercise: Equatable {
    @Guide(description: "入力にある筋力トレーニングの種目名。別名を正式名称へ変換せず、入力どおりに返す。")
    var exerciseName: String

    @Guide(description: "共通条件の繰り返しか、個別に列挙されたセット。")
    var setPattern: GeneratedWorkoutQuickInputSetPattern
}

@Generable
enum GeneratedWorkoutQuickInputSetPattern: Equatable {
    case repeated(GeneratedRepeatedWorkoutSets)

    case explicit(GeneratedExplicitWorkoutSets)
}

@Generable
struct GeneratedRepeatedWorkoutSets: Equatable {
    @Guide(description: "入力で明示されたセット数。")
    var setCount: Int

    @Guide(description: "全セットに共通する重量kg。重量がなければnil。自重は0。")
    var defaultWeightKg: Double?

    @Guide(description: "全セットに共通する回数。回数がなければnil。")
    var defaultReps: Int?

    @Guide(description: "『最後だけ8回』など、特定セットだけに適用する差分。", .maximumCount(10))
    var overrides: [GeneratedWorkoutQuickInputOverride]
}

@Generable
struct GeneratedExplicitWorkoutSets: Equatable {
    @Guide(description: "入力で個別に列挙されたセット。入力順。", .maximumCount(10))
    var sets: [GeneratedWorkoutQuickInputSet]
}

@Generable
struct GeneratedWorkoutQuickInputOverride: Equatable {
    @Guide(description: "差分を適用する1始まりのセット番号。『最後』はsetCountと同じ番号。")
    var setNumber: Int

    @Guide(description: "このセットだけに明示された重量kg。重量の差分がなければnil。")
    var weightKg: Double?

    @Guide(description: "このセットだけに明示された回数。回数の差分がなければnil。")
    var reps: Int?
}

@Generable
struct GeneratedWorkoutQuickInputSet: Equatable {
    @Guide(description: "このセットに明示された重量kg。重量が書かれていなければnil。")
    var weightKg: Double?

    @Guide(description: "このセットに明示された回数。回数が書かれていなければnil。")
    var reps: Int?
}

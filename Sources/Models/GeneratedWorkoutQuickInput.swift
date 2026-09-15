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

    @Guide(description: "『3セット』など、入力で明示されたセット数。明示されていなければnil。")
    var setCount: Int?

    @Guide(description: "全セットに共通する、入力で明示された重量kg。重量がなければnil。自重は0。")
    var defaultWeightKg: Double?

    @Guide(description: "全セットに共通する、入力で明示された回数。回数がなければnil。")
    var defaultReps: Int?

    @Guide(description: "『最後だけ8回』など、特定セットだけに適用する差分。", .maximumCount(10))
    var overrides: [GeneratedWorkoutQuickInputOverride]

    @Guide(description: "各セットが個別に列挙された場合だけ使用するセット。繰り返し表現の展開には使用しない。", .maximumCount(10))
    var explicitSets: [GeneratedWorkoutQuickInputSet]
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

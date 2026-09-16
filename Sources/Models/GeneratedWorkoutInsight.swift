import Foundation
import FoundationModels

@Generable
struct GeneratedWorkoutInsight: Equatable {
    @Guide(description: "今日のWorkoutの短い見出し。与えられた事実だけを使い、18文字程度までにする。")
    var headline: String

    @Guide(description: "与えられたWorkoutの事実だけを使った1〜2文の振り返り。新しい数値、種目、PR、比較結果を追加しない。")
    var message: String
}

import Foundation
import FoundationModels

@Generable
struct GeneratedWorkoutInsight: Equatable {
    @Guide(
        description: """
            今日のWorkoutの短い見出し。与えられた事実だけを使う。18文字程度まで。
            """
    )
    var headline: String

    @Guide(
        description: """
            与えられたWorkoutの事実だけを使った1〜2文の振り返り。
            新しい数値、種目、自己ベスト、比較結果を追加しない。
            """
    )
    var message: String
}

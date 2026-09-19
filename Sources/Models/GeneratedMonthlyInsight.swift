import Foundation
import FoundationModels

@Generable
struct GeneratedMonthlyInsight: Equatable {
    @Guide(
        description: """
            与えられた月間トレーニングの事実だけを使った1〜2文の短いインサイト。
            入力に存在しない数値、種目、自己ベスト、比較結果を追加しない。
            """
    )
    var message: String
}

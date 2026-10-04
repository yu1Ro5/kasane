import Foundation

/// 重量候補を1件返す。候補の算出では入力や保存済み記録を変更しない。
enum WeightSuggestionProvider {
    static func suggestion(
        at setIndex: Int,
        currentSets: [SetEntryDraft],
        previousWeights: [Double],
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> String? {
        guard setIndex >= 0, setIndex <= currentSets.count else { return nil }
        let weight: Double
        if setIndex > 0 {
            // 回数の入力状態に依存せず、既存の重量入力ルールで検証する。
            let previous = SetEntryDraft(weight: currentSets[setIndex - 1].weight, reps: "1")
            guard let values = previous.values(decimalSeparator: decimalSeparator) else { return nil }
            weight = values.weight
        } else {
            guard let previous = previousWeights.last(where: { $0.isFinite && $0 >= 0 }) else { return nil }
            weight = previous
        }
        return WorkoutSetDisplayFormatter.editableWeightValue(weight)
            .replacingOccurrences(of: ".", with: decimalSeparator)
    }
}

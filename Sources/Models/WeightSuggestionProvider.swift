import Foundation

typealias WeightSuggestionWorkout = SuggestionWorkout<Double>

enum WeightSuggestionProvider {
    static let defaultSuggestions: [Double] = [
        5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100, 120, 140, 160, 180, 200,
    ]

    static func suggestions(
        for exerciseID: UUID,
        currentSessionID: UUID,
        workouts: [WeightSuggestionWorkout],
        at setIndex: Int,
        currentSets: [SetEntryDraft],
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> [String] {
        guard setIndex >= 0 && setIndex <= currentSets.count else { return [] }
        let previous = currentSets.prefix(setIndex).reversed().compactMap { draft -> Double? in
            SetEntryDraft(weight: draft.weight, reps: "1").values(decimalSeparator: decimalSeparator)?.weight
        }.first
        let weights = SuggestionRanking.suggestions(
            for: exerciseID,
            currentSessionID: currentSessionID,
            workouts: workouts,
            currentPrevious: previous,
            defaults: defaultSuggestions,
            isValid: { $0.isFinite && $0 >= 0 },
            sortedDefaults: { previous in
                defaultSuggestions.sorted {
                    let left = abs($0 - previous)
                    let right = abs($1 - previous)
                    return left == right ? $0 < $1 : left < right
                }
            }
        )
        return weights.map {
            WorkoutSetDisplayFormatter.editableWeightValue($0)
                .replacingOccurrences(of: ".", with: decimalSeparator)
        }
    }
}

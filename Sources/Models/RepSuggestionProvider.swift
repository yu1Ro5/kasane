import Foundation

typealias RepSuggestionWorkout = SuggestionWorkout<Int>

enum RepSuggestionProvider {
    static let defaultSuggestions = [8, 10, 12, 15]

    static func suggestions(
        for exerciseID: UUID,
        currentSessionID: UUID,
        workouts: [RepSuggestionWorkout],
        at setIndex: Int = 0,
        currentSets: [SetEntryDraft] = [],
        limit: Int = 4
    ) -> [Int] {
        guard setIndex >= 0 && setIndex <= currentSets.count else { return [] }
        let previous = currentSets.prefix(setIndex).reversed().compactMap { draft -> Int? in
            guard draft.reps.range(of: "^[0-9]+$", options: .regularExpression) != nil,
                let reps = Int(draft.reps), reps > 0 else { return nil }
            return reps
        }.first
        return SuggestionRanking.suggestions(
            for: exerciseID,
            currentSessionID: currentSessionID,
            workouts: workouts,
            currentPrevious: previous,
            defaults: defaultSuggestions,
            isValid: { $0 >= 1 },
            sortedDefaults: { _ in defaultSuggestions },
            limit: min(limit, 4)
        )
    }
}

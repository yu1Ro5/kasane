import Foundation

/// 1種目について、1 Workout 内のセット順を保持した履歴。
struct SuggestionWorkout<Value: Hashable & Comparable> {
    let sessionID: UUID
    let startedAt: Date
    let endedAt: Date?
    let exerciseID: UUID
    let values: [Value]
}

enum SuggestionRanking {
    static func suggestions<Value: Hashable & Comparable>(
        for exerciseID: UUID,
        currentSessionID: UUID,
        workouts: [SuggestionWorkout<Value>],
        currentPrevious: Value?,
        defaults: [Value],
        isValid: (Value) -> Bool,
        sortedDefaults: (Value) -> [Value],
        limit: Int = 4
    ) -> [Value] {
        guard limit > 0 else { return [] }
        let recent = workouts.filter {
            $0.endedAt != nil && $0.sessionID != currentSessionID && $0.exerciseID == exerciseID
        }.sorted {
            if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
            return $0.sessionID.uuidString < $1.sessionID.uuidString
        }.prefix(10)

        var scores: [Value: (points: Int, recentIndex: Int, count: Int)] = [:]
        for (index, workout) in recent.enumerated() {
            for value in workout.values where isValid(value) {
                let old = scores[value] ?? (0, index, 0)
                scores[value] = (old.points + 10 - index, min(old.recentIndex, index), old.count + 1)
            }
        }
        let ranked = scores.keys.sorted { lhs, rhs in
            guard let left = scores[lhs], let right = scores[rhs] else { return lhs < rhs }
            if left.points != right.points { return left.points > right.points }
            if left.recentIndex != right.recentIndex { return left.recentIndex < right.recentIndex }
            if left.count != right.count { return left.count > right.count }
            return lhs < rhs
        }
        let historicalPrevious = recent.compactMap { $0.values.last(where: isValid) }.first
        let previous = currentPrevious.flatMap { isValid($0) ? $0 : nil } ?? historicalPrevious
        var result: [Value] = []
        if let previous { result.append(previous) }
        for value in ranked where result.count < limit && !result.contains(value) {
            result.append(value)
        }
        let fallback = previous.map(sortedDefaults) ?? defaults
        for value in fallback where result.count < limit && isValid(value) && !result.contains(value) {
            result.append(value)
        }
        return result
    }
}

import Foundation

/// 回数候補の算出に必要な、1 Workout分の値だけを保持する入力。
struct RepSuggestionWorkout: Equatable {
    let sessionID: UUID
    let startedAt: Date
    let endedAt: Date?
    let exerciseID: UUID
    let reps: [Int]
}

/// 完了済みWorkoutの利用頻度から、決定論的に回数候補を生成する。
enum RepSuggestionProvider {
    static let defaultSuggestions = [8, 10, 12, 15]

    static func suggestions(
        for exerciseID: UUID,
        currentSessionID: UUID,
        workouts: [RepSuggestionWorkout],
        limit: Int = 4
    ) -> [Int] {
        guard limit > 0 else { return [] }

        let recentWorkouts =
            workouts
            .filter {
                $0.endedAt != nil
                    && $0.sessionID != currentSessionID
                    && $0.exerciseID == exerciseID
            }
            .sorted {
                if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
                return $0.sessionID.uuidString < $1.sessionID.uuidString
            }
            .prefix(20)

        var frequencies: [Int: Int] = [:]
        var mostRecentUse: [Int: Date] = [:]
        for workout in recentWorkouts {
            for reps in workout.reps where reps >= 1 {
                frequencies[reps, default: 0] += 1
                mostRecentUse[reps] = max(mostRecentUse[reps] ?? .distantPast, workout.startedAt)
            }
        }

        var result = frequencies.keys.sorted { lhs, rhs in
            let lhsFrequency = frequencies[lhs, default: 0]
            let rhsFrequency = frequencies[rhs, default: 0]
            if lhsFrequency != rhsFrequency { return lhsFrequency > rhsFrequency }

            let lhsRecentUse = mostRecentUse[lhs] ?? .distantPast
            let rhsRecentUse = mostRecentUse[rhs] ?? .distantPast
            if lhsRecentUse != rhsRecentUse { return lhsRecentUse > rhsRecentUse }
            return lhs < rhs
        }

        for value in defaultSuggestions where result.count < limit && !result.contains(value) {
            result.append(value)
        }
        return Array(result.prefix(limit))
    }
}

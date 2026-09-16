import Foundation

/// Workout完了時の振り返り生成にだけ使う、永続化しない確定済み事実。
struct WorkoutInsightFacts: Equatable {
    let duration: TimeInterval
    let exerciseCount: Int
    let setCount: Int
    let totalVolume: Double
    let personalRecords: [WorkoutInsightPersonalRecordFact]
    let exerciseComparisons: [WorkoutInsightExerciseComparisonFact]

    var isEligibleForGeneration: Bool {
        !personalRecords.isEmpty
            || exerciseComparisons.contains {
                $0.maxWeightDifference > 0 || $0.volumeDifference > 0
            }
    }
}

struct WorkoutInsightPersonalRecordFact: Equatable {
    let exerciseName: String
    let previousBest: Double
    let newBest: Double
    let improvement: Double
}

struct WorkoutInsightExerciseComparisonFact: Equatable {
    let exerciseName: String
    let currentMaxWeight: Double
    let previousMaxWeight: Double
    let maxWeightDifference: Double
    let currentVolume: Double
    let previousVolume: Double
    let volumeDifference: Double
}

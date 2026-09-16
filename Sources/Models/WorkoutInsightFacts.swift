import Foundation

/// Workout履歴から確定した、振り返り生成専用の非永続データ。
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

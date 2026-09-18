import Foundation

/// 月間インサイト生成にだけ使う、Overviewの集計から組み立てた確定済み事実。
struct MonthlyInsightFacts: Equatable, Hashable {
    let month: Date
    let workoutCount: Int
    let totalDuration: TimeInterval
    let totalVolume: Double
    let activeDays: Int
    let streakWeeks: Int
    let personalRecord: MonthlyInsightHighlightFact?
    let improvement: MonthlyInsightHighlightFact?
    let mostFrequentExercise: MonthlyInsightExerciseFrequencyFact?

    var isEligibleForGeneration: Bool {
        guard workoutCount > 0 else { return false }
        return workoutCount > 1
            || personalRecord != nil
            || improvement != nil
            || streakWeeks > 1
            || (mostFrequentExercise?.workoutCount ?? 0) > 1
    }
}

struct MonthlyInsightHighlightFact: Equatable, Hashable {
    let exerciseName: String
    let weight: Double
    let improvement: Double
    let date: Date
}

struct MonthlyInsightExerciseFrequencyFact: Equatable, Hashable {
    let exerciseName: String
    let workoutCount: Int
}

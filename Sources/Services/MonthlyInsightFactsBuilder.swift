import Foundation

/// OverviewStatsをSource of Truthとして、生成モデルへ渡す月間事実を組み立てる。
enum MonthlyInsightFactsBuilder {
    static func build(
        stats: OverviewStats,
        sessions: [WorkoutSession],
        calendar: Calendar
    ) -> MonthlyInsightFacts {
        MonthlyInsightFacts(
            month: stats.month,
            workoutCount: stats.workoutCount,
            totalDuration: stats.duration,
            totalVolume: stats.totalVolume,
            activeDays: stats.dailyWorkoutCounts.count,
            streakWeeks: stats.streak,
            personalRecord: stats.personalRecord.map(highlightFact),
            improvement: stats.improvement.map(highlightFact),
            mostFrequentExercise: mostFrequentExercise(
                in: sessions, month: stats.month, calendar: calendar)
        )
    }

    private static func highlightFact(_ highlight: OverviewStats.Highlight) -> MonthlyInsightHighlightFact {
        MonthlyInsightHighlightFact(
            exerciseName: highlight.exerciseName,
            weight: highlight.weight,
            improvement: highlight.improvement,
            date: highlight.date
        )
    }

    private static func mostFrequentExercise(
        in sessions: [WorkoutSession],
        month: Date,
        calendar: Calendar
    ) -> MonthlyInsightExerciseFrequencyFact? {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return nil }
        var frequencies: [UUID: (name: String, count: Int)] = [:]

        for session in sessions where session.endedAt != nil && interval.contains(session.startedAt) {
            var exercisesInWorkout: [UUID: String] = [:]
            for entry in session.exerciseEntries where !entry.setEntries.isEmpty {
                guard let exerciseID = entry.exercise?.id else { continue }
                exercisesInWorkout[exerciseID] = entry.exerciseNameSnapshot
            }
            for (exerciseID, name) in exercisesInWorkout {
                let previous = frequencies[exerciseID]?.count ?? 0
                frequencies[exerciseID] = (name, previous + 1)
            }
        }

        guard
            let result = frequencies.sorted(by: {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key.uuidString < $1.key.uuidString
            }).first
        else { return nil }
        return MonthlyInsightExerciseFrequencyFact(
            exerciseName: result.value.name,
            workoutCount: result.value.count
        )
    }
}

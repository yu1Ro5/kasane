import Foundation

/// 保存済みWorkoutから、生成モデルへ渡せる確定済み事実だけを組み立てる。
enum WorkoutInsightFactsBuilder {
    static func build(
        summary: WorkoutCompletionSummary,
        session: WorkoutSession,
        personalRecords: [PersonalRecordAchievement],
        sessions: [WorkoutSession]
    ) -> WorkoutInsightFacts {
        let completedEntries = session.exerciseEntries
            .filter { !$0.setEntries.isEmpty }
            .sorted { $0.order < $1.order }

        let comparisons = completedEntries.compactMap { entry in
            comparison(for: entry, in: session, sessions: sessions)
        }

        return WorkoutInsightFacts(
            duration: summary.duration,
            exerciseCount: summary.exerciseCount,
            setCount: summary.setCount,
            totalVolume: completedEntries.reduce(0) { $0 + volume(of: $1.setEntries) },
            personalRecords: personalRecords.map {
                WorkoutInsightPersonalRecordFact(
                    exerciseName: $0.exerciseName,
                    previousBest: $0.previousBest,
                    newBest: $0.newBest,
                    improvement: $0.improvement
                )
            },
            exerciseComparisons: comparisons
        )
    }

    /// 不正な負数を集計へ含めない、Workout insight共通のvolume計算。
    static func volume(of sets: [SetEntry]) -> Double {
        sets.reduce(0) { result, set in
            result + max(set.weightKg, 0) * Double(max(set.reps, 0))
        }
    }

    private static func comparison(
        for entry: ExerciseEntry,
        in session: WorkoutSession,
        sessions: [WorkoutSession]
    ) -> WorkoutInsightExerciseComparisonFact? {
        guard
            let previous = PreviousWorkoutRecordContent.find(
                for: entry,
                in: session,
                sessions: sessions
            ),
            let currentMaxWeight = entry.setEntries.map(\.weightKg).max(),
            let previousMaxWeight = previous.setEntries.map(\.weightKg).max()
        else { return nil }

        let currentVolume = volume(of: entry.setEntries)
        let previousVolume = volume(of: previous.setEntries)
        return WorkoutInsightExerciseComparisonFact(
            exerciseName: entry.exerciseNameSnapshot,
            currentMaxWeight: currentMaxWeight,
            previousMaxWeight: previousMaxWeight,
            maxWeightDifference: currentMaxWeight - previousMaxWeight,
            currentVolume: currentVolume,
            previousVolume: previousVolume,
            volumeDifference: currentVolume - previousVolume
        )
    }
}

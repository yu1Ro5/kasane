import Foundation

enum WorkoutVolumeCalculator {
    static func volume(of setEntries: [SetEntry]) -> Double {
        setEntries.reduce(0) {
            $0 + max($1.weightKg, 0) * Double(max($1.reps, 0))
        }
    }
}

/// 保存済みWorkoutから、AIに計算を委ねない確定済みfactsを構築する。
struct WorkoutInsightFactsBuilder {
    func build(
        summary: WorkoutCompletionSummary,
        session: WorkoutSession,
        personalRecords: [PersonalRecordAchievement],
        sessions: [WorkoutSession]
    ) -> WorkoutInsightFacts {
        let completedEntries = session.exerciseEntries
            .filter { !WorkoutSessionContent.setEntries(for: $0).isEmpty }
            .sorted { $0.order < $1.order }

        let comparisons = completedEntries.compactMap { entry in
            guard
                let previous = PreviousWorkoutRecordContent.find(
                    for: entry,
                    in: session,
                    sessions: sessions
                ),
                !previous.setEntries.isEmpty
            else { return nil }

            let currentSets = WorkoutSessionContent.setEntries(for: entry)
            let currentMaxWeight = currentSets.map(\.weightKg).max() ?? 0
            let previousMaxWeight = previous.setEntries.map(\.weightKg).max() ?? 0
            let currentVolume = WorkoutVolumeCalculator.volume(of: currentSets)
            let previousVolume = WorkoutVolumeCalculator.volume(of: previous.setEntries)
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

        return WorkoutInsightFacts(
            duration: summary.duration,
            exerciseCount: summary.exerciseCount,
            setCount: summary.setCount,
            totalVolume: WorkoutVolumeCalculator.volume(
                of: completedEntries.flatMap { WorkoutSessionContent.setEntries(for: $0) }
            ),
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
}

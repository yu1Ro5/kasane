import Foundation

/// Detects maximum-weight records without persisting derived achievement data.
enum PersonalRecordDetector {
    /// Compares a workout with workouts completed before it started.
    static func achievements(
        for currentWorkout: WorkoutSession,
        among workouts: [WorkoutSession]
    ) -> [PersonalRecordAchievement] {
        let currentMaximums = maximumWeights(in: currentWorkout)
        guard !currentMaximums.isEmpty else { return [] }

        var previousMaximums: [UUID: Double] = [:]
        for workout in workouts where isEligibleHistory(workout, for: currentWorkout) {
            for (exerciseID, maximum) in maximumWeights(in: workout) {
                previousMaximums[exerciseID] = max(previousMaximums[exerciseID] ?? maximum, maximum)
            }
        }

        var processedExerciseIDs: Set<UUID> = []
        return currentWorkout.exerciseEntries.sorted { $0.order < $1.order }.compactMap { entry in
            guard
                let exercise = entry.exercise,
                processedExerciseIDs.insert(exercise.id).inserted,
                let newBest = currentMaximums[exercise.id],
                let previousBest = previousMaximums[exercise.id],
                newBest > previousBest
            else { return nil }

            return PersonalRecordAchievement(
                exerciseID: exercise.id,
                exerciseName: entry.exerciseNameSnapshot,
                previousBest: previousBest,
                newBest: newBest
            )
        }
    }

    private static func isEligibleHistory(
        _ workout: WorkoutSession,
        for currentWorkout: WorkoutSession
    ) -> Bool {
        workout.id != currentWorkout.id
            && workout.endedAt != nil
            && workout.startedAt < currentWorkout.startedAt
    }

    private static func maximumWeights(in workout: WorkoutSession) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for entry in workout.exerciseEntries {
            guard let exerciseID = entry.exercise?.id, let maximum = entry.setEntries.map(\.weightKg).max()
            else { continue }
            result[exerciseID] = max(result[exerciseID] ?? maximum, maximum)
        }
        return result
    }
}

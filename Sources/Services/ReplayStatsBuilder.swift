import Foundation

/// Builds annual Replay metrics from the current, non-persisted workout history.
enum ReplayStatsBuilder {
    private static let longWorkoutThreshold: TimeInterval = 6 * 60 * 60

    static func build(
        year: Int,
        workouts: [WorkoutSession],
        calendar: Calendar = .current
    ) -> YearlyReplayStats {
        let allWorkouts = unique(workouts)
        guard let interval = yearInterval(for: year, calendar: calendar) else {
            return emptyStats(year: year)
        }

        let included = allWorkouts.filter {
            $0.endedAt != nil
                && $0.startedAt >= interval.start
                && $0.startedAt < interval.end
        }
        let ordered = included.sorted(by: workoutOrder)

        var totalVolume = 0.0
        var totalDuration: TimeInterval = 0
        var totalSetCount = 0
        var hasLongWorkout = false

        for workout in included {
            if let endedAt = workout.endedAt {
                let recordedDuration = endedAt.timeIntervalSince(workout.startedAt)
                let duration = recordedDuration.isFinite && recordedDuration > 0 ? recordedDuration : 0
                if duration > longWorkoutThreshold {
                    hasLongWorkout = true
                }
                let nextDuration = totalDuration + duration
                if nextDuration.isFinite {
                    totalDuration = nextDuration
                }
            }

            for set in uniqueSets(in: workout) {
                if set.reps >= 1 {
                    totalSetCount += 1
                }
                guard set.reps > 0, set.weightKg.isFinite else { continue }
                let weight = max(set.weightKg, 0)
                let volume = weight * Double(set.reps)
                guard volume.isFinite else { continue }
                let nextVolume = totalVolume + volume
                if nextVolume.isFinite {
                    totalVolume = nextVolume
                }
            }
        }

        return YearlyReplayStats(
            year: year,
            workoutCount: included.count,
            totalVolume: totalVolume,
            totalDuration: totalDuration,
            totalSetCount: totalSetCount,
            hasWorkoutLongerThanSixHours: hasLongWorkout,
            mostTrained: mostTrained(in: ordered),
            biggestGrowth: biggestGrowth(in: ordered),
            personalRecordCount: included.reduce(0) {
                $0 + PersonalRecordDetector.achievements(for: $1, among: allWorkouts).count
            }
        )
    }

    private struct MostTrainedAccumulator {
        var exerciseName: String
        var workoutCount = 0
        var setCount = 0
    }

    private static func mostTrained(in workouts: [WorkoutSession]) -> YearlyReplayStats.MostTrained? {
        var accumulators: [UUID: MostTrainedAccumulator] = [:]

        for workout in workouts {
            var names: [UUID: String] = [:]
            var setCounts: [UUID: Int] = [:]
            for entry in uniqueEntries(in: workout).sorted(by: entryOrder) {
                guard let exerciseID = entry.exercise?.id else { continue }
                if names[exerciseID] == nil {
                    names[exerciseID] = entry.exerciseNameSnapshot
                }
                setCounts[exerciseID, default: 0] += unique(entry.setEntries).filter { $0.reps >= 1 }.count
            }

            for (exerciseID, name) in names {
                var accumulator = accumulators[exerciseID]
                    ?? MostTrainedAccumulator(exerciseName: name)
                accumulator.exerciseName = name
                accumulator.workoutCount += 1
                accumulator.setCount += setCounts[exerciseID, default: 0]
                accumulators[exerciseID] = accumulator
            }
        }

        return accumulators.map {
            YearlyReplayStats.MostTrained(
                exerciseID: $0.key,
                exerciseName: $0.value.exerciseName,
                workoutCount: $0.value.workoutCount,
                setCount: $0.value.setCount
            )
        }.min(by: mostTrainedRanksBefore)
    }

    private struct GrowthPoint {
        let exerciseName: String
        let estimatedOneRepMax: Double
    }

    private static func biggestGrowth(in workouts: [WorkoutSession]) -> YearlyReplayStats.BiggestGrowth? {
        var pointsByExercise: [UUID: [GrowthPoint]] = [:]

        for workout in workouts {
            var workoutMaximums: [UUID: GrowthPoint] = [:]
            for entry in uniqueEntries(in: workout).sorted(by: entryOrder) {
                guard let exerciseID = entry.exercise?.id else { continue }
                for set in unique(entry.setEntries).sorted(by: setOrder) {
                    guard let estimate = estimatedOneRepMax(for: set) else { continue }
                    if estimate > (workoutMaximums[exerciseID]?.estimatedOneRepMax ?? -.infinity) {
                        workoutMaximums[exerciseID] = GrowthPoint(
                            exerciseName: entry.exerciseNameSnapshot,
                            estimatedOneRepMax: estimate
                        )
                    }
                }
            }
            for (exerciseID, maximum) in workoutMaximums {
                pointsByExercise[exerciseID, default: []].append(maximum)
            }
        }

        let candidates = pointsByExercise.compactMap { exerciseID, points -> YearlyReplayStats.BiggestGrowth? in
            guard points.count >= 2, let baseline = points.first else { return nil }
            guard let peak = points.dropFirst().max(by: {
                $0.estimatedOneRepMax < $1.estimatedOneRepMax
            }) else { return nil }
            let absoluteGrowth = peak.estimatedOneRepMax - baseline.estimatedOneRepMax
            guard absoluteGrowth > 0, absoluteGrowth.isFinite else { return nil }
            let growthRate = absoluteGrowth / baseline.estimatedOneRepMax * 100
            guard growthRate.isFinite, growthRate > 0 else { return nil }
            return YearlyReplayStats.BiggestGrowth(
                exerciseID: exerciseID,
                exerciseName: peak.exerciseName,
                baselineEstimatedOneRepMax: baseline.estimatedOneRepMax,
                peakEstimatedOneRepMax: peak.estimatedOneRepMax,
                growthRate: growthRate
            )
        }

        return candidates.min(by: growthRanksBefore)
    }

    private static func estimatedOneRepMax(for set: SetEntry) -> Double? {
        guard
            (1...15).contains(set.reps),
            !set.isWarmup,
            set.weightKg.isFinite,
            set.weightKg > 0
        else { return nil }
        let estimate = set.reps == 1
            ? set.weightKg
            : set.weightKg * (1 + Double(set.reps) / 30)
        return estimate.isFinite ? estimate : nil
    }

    private static func mostTrainedRanksBefore(
        _ lhs: YearlyReplayStats.MostTrained,
        _ rhs: YearlyReplayStats.MostTrained
    ) -> Bool {
        if lhs.workoutCount != rhs.workoutCount {
            return lhs.workoutCount > rhs.workoutCount
        }
        if lhs.setCount != rhs.setCount {
            return lhs.setCount > rhs.setCount
        }
        return lhs.exerciseID.uuidString < rhs.exerciseID.uuidString
    }

    private static func growthRanksBefore(
        _ lhs: YearlyReplayStats.BiggestGrowth,
        _ rhs: YearlyReplayStats.BiggestGrowth
    ) -> Bool {
        if lhs.growthRate != rhs.growthRate {
            return lhs.growthRate > rhs.growthRate
        }
        if lhs.absoluteGrowth != rhs.absoluteGrowth {
            return lhs.absoluteGrowth > rhs.absoluteGrowth
        }
        return lhs.exerciseID.uuidString < rhs.exerciseID.uuidString
    }

    private static func yearInterval(for year: Int, calendar: Calendar) -> DateInterval? {
        guard
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let end = calendar.date(byAdding: .year, value: 1, to: start),
            end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func workoutOrder(_ lhs: WorkoutSession, _ rhs: WorkoutSession) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt < rhs.startedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func entryOrder(_ lhs: ExerciseEntry, _ rhs: ExerciseEntry) -> Bool {
        if lhs.order != rhs.order {
            return lhs.order < rhs.order
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func setOrder(_ lhs: SetEntry, _ rhs: SetEntry) -> Bool {
        if lhs.order != rhs.order {
            return lhs.order < rhs.order
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func uniqueEntries(in workout: WorkoutSession) -> [ExerciseEntry] {
        unique(workout.exerciseEntries)
    }

    private static func uniqueSets(in workout: WorkoutSession) -> [SetEntry] {
        var seen = Set<UUID>()
        return uniqueEntries(in: workout).flatMap(\.setEntries).filter {
            seen.insert($0.id).inserted
        }
    }

    private static func unique<Model: Identifiable>(_ models: [Model]) -> [Model]
    where Model.ID == UUID {
        var seen = Set<UUID>()
        return models.filter { seen.insert($0.id).inserted }
    }

    private static func emptyStats(year: Int) -> YearlyReplayStats {
        YearlyReplayStats(
            year: year,
            workoutCount: 0,
            totalVolume: 0,
            totalDuration: 0,
            totalSetCount: 0,
            hasWorkoutLongerThanSixHours: false,
            mostTrained: nil,
            biggestGrowth: nil,
            personalRecordCount: 0
        )
    }
}

import Foundation

enum ExerciseProgressMetric: String, CaseIterable, Identifiable {
    case maxWeight = "最大重量"
    case volume = "総ボリューム"
    case reps = "回数"

    var id: Self { self }
}

struct ExerciseProgressPoint: Identifiable, Equatable {
    let workoutID: UUID
    let completedAt: Date
    let maxWeightKg: Double
    let maxWeightReps: Int
    let volumeKg: Double
    let totalReps: Int
    let isPersonalRecord: Bool

    var id: UUID { workoutID }

    func value(for metric: ExerciseProgressMetric) -> Double {
        switch metric {
        case .maxWeight: maxWeightKg
        case .volume: volumeKg
        case .reps: Double(totalReps)
        }
    }
}

struct ExerciseProgressStats: Equatable {
    let exerciseID: UUID
    let exerciseName: String
    let points: [ExerciseProgressPoint]

    var currentBest: Double? { points.map(\.maxWeightKg).max() }
    var firstBest: Double? { points.first?.maxWeightKg }
    var growthAmount: Double? {
        guard let currentBest, let firstBest else { return nil }
        return currentBest - firstBest
    }
    var growthPercentage: Double? {
        guard let growthAmount, let firstBest, firstBest > 0 else { return nil }
        let percentage = growthAmount / firstBest * 100
        return percentage.isFinite ? percentage : nil
    }
    var personalRecordDate: Date? {
        guard let currentBest else { return nil }
        return points.first { $0.maxWeightKg == currentBest }?.completedAt
    }
    var recentRecords: [ExerciseProgressPoint] { Array(points.reversed().prefix(3)) }

    func firstValue(for metric: ExerciseProgressMetric) -> Double? {
        points.first?.value(for: metric)
    }

    func currentValue(for metric: ExerciseProgressMetric) -> Double? {
        switch metric {
        case .maxWeight: currentBest
        case .volume, .reps: points.last?.value(for: metric)
        }
    }

    func change(for metric: ExerciseProgressMetric) -> Double? {
        guard let first = firstValue(for: metric), let current = currentValue(for: metric) else {
            return nil
        }
        return current - first
    }
}

enum ExerciseProgressBuilder {
    static func build(exerciseID: UUID, entries: [ExerciseEntry]) -> ExerciseProgressStats? {
        let matchingEntries = entries.filter { $0.exercise?.id == exerciseID }
        guard let exercise = matchingEntries.compactMap(\.exercise).first else { return nil }

        var aggregates: [UUID: WorkoutAggregate] = [:]
        let orderedEntries = matchingEntries.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
        for entry in orderedEntries {
            guard let session = entry.workoutSession, let completedAt = session.endedAt else { continue }
            let validSets = entry.setEntries
                .filter { $0.weightKg.isFinite && $0.weightKg >= 0 && $0.reps > 0 }
                .sorted {
                    if $0.order != $1.order { return $0.order < $1.order }
                    return $0.id.uuidString < $1.id.uuidString
                }
            guard !validSets.isEmpty else { continue }

            var aggregate = aggregates[session.id] ?? WorkoutAggregate(completedAt: completedAt)
            for set in validSets {
                let setVolume = set.weightKg * Double(set.reps)
                let updatedVolume = aggregate.volumeKg + setVolume
                if setVolume.isFinite, updatedVolume.isFinite {
                    aggregate.volumeKg = updatedVolume
                }
                aggregate.totalReps += set.reps
                if aggregate.maxWeightKg == nil || set.weightKg > (aggregate.maxWeightKg ?? 0) {
                    aggregate.maxWeightKg = set.weightKg
                    aggregate.maxWeightReps = set.reps
                }
            }
            aggregates[session.id] = aggregate
        }

        let chronological = aggregates.compactMap { workoutID, aggregate -> RawPoint? in
            guard let maxWeightKg = aggregate.maxWeightKg else { return nil }
            return RawPoint(
                workoutID: workoutID,
                completedAt: aggregate.completedAt,
                maxWeightKg: maxWeightKg,
                maxWeightReps: aggregate.maxWeightReps,
                volumeKg: aggregate.volumeKg,
                totalReps: aggregate.totalReps
            )
        }.sorted {
            if $0.completedAt != $1.completedAt { return $0.completedAt < $1.completedAt }
            return $0.workoutID.uuidString < $1.workoutID.uuidString
        }

        var previousBest: Double?
        let points = chronological.map { point in
            let isPersonalRecord = previousBest.map { point.maxWeightKg > $0 } ?? false
            previousBest = max(previousBest ?? point.maxWeightKg, point.maxWeightKg)
            return ExerciseProgressPoint(
                workoutID: point.workoutID,
                completedAt: point.completedAt,
                maxWeightKg: point.maxWeightKg,
                maxWeightReps: point.maxWeightReps,
                volumeKg: point.volumeKg,
                totalReps: point.totalReps,
                isPersonalRecord: isPersonalRecord
            )
        }
        return ExerciseProgressStats(exerciseID: exerciseID, exerciseName: exercise.name, points: points)
    }

    private struct WorkoutAggregate {
        let completedAt: Date
        var maxWeightKg: Double?
        var maxWeightReps = 0
        var volumeKg = 0.0
        var totalReps = 0
    }

    private struct RawPoint {
        let workoutID: UUID
        let completedAt: Date
        let maxWeightKg: Double
        let maxWeightReps: Int
        let volumeKg: Double
        let totalReps: Int
    }
}

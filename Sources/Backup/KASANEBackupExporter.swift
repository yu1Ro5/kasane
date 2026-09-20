import Foundation
import SwiftData

@MainActor
struct KASANEBackupExporter {
    let container: ModelContainer

    func makeBackup(now: Date = Date()) throws -> KASANEBackup {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
            .map {
                ExerciseBackup(
                    id: $0.id,
                    name: $0.name,
                    primaryBodyPart: $0.primaryBodyPart,
                    isArchived: $0.isArchived
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let workouts = try context.fetch(FetchDescriptor<WorkoutSession>())
            .map { workout in
                WorkoutBackup(
                    id: workout.id,
                    startedAt: workout.startedAt,
                    endedAt: workout.endedAt,
                    note: workout.note,
                    exerciseEntries: workout.exerciseEntries.map { entry in
                        ExerciseEntryBackup(
                            id: entry.id,
                            exerciseID: entry.exercise?.id,
                            exerciseNameSnapshot: entry.exerciseNameSnapshot,
                            primaryBodyPartSnapshot: entry.primaryBodyPartSnapshot,
                            order: entry.order,
                            sets: entry.setEntries.map { set in
                                SetEntryBackup(
                                    id: set.id,
                                    order: set.order,
                                    weightKg: set.weightKg,
                                    reps: set.reps,
                                    isWarmup: set.isWarmup
                                )
                            }
                            .sorted(by: Self.orderSets)
                        )
                    }
                    .sorted(by: Self.orderEntries)
                )
            }
            .sorted(by: Self.orderWorkouts)
        return KASANEBackup(
            formatVersion: KASANEBackup.currentFormatVersion,
            exportedAt: now,
            appVersion: AppVersion.current,
            exercises: exercises,
            workouts: workouts
        )
    }

    func makeJSONData(now: Date = Date()) throws -> Data {
        try KASANEBackupCoding.encode(makeBackup(now: now))
    }

    private static func orderWorkouts(_ lhs: WorkoutBackup, _ rhs: WorkoutBackup) -> Bool {
        lhs.startedAt == rhs.startedAt
            ? lhs.id.uuidString < rhs.id.uuidString
            : lhs.startedAt < rhs.startedAt
    }

    private static func orderEntries(_ lhs: ExerciseEntryBackup, _ rhs: ExerciseEntryBackup) -> Bool {
        lhs.order == rhs.order ? lhs.id.uuidString < rhs.id.uuidString : lhs.order < rhs.order
    }

    private static func orderSets(_ lhs: SetEntryBackup, _ rhs: SetEntryBackup) -> Bool {
        lhs.order == rhs.order ? lhs.id.uuidString < rhs.id.uuidString : lhs.order < rhs.order
    }
}

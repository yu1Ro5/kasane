import Foundation
import SwiftData

enum KASANEBackupImportError: Error, LocalizedError {
    case workoutInProgress

    var errorDescription: String? {
        "進行中のワークアウトがあります。完了または破棄してからバックアップを復元してください。"
    }
}

@MainActor
struct KASANEBackupImporter {
    let container: ModelContainer
    var beforeCommit: (ModelContext) throws -> Void = { _ in }

    func importBackup(_ backup: KASANEBackup) throws {
        try KASANEBackupValidator.validate(backup)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var inProgress = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        inProgress.fetchLimit = 1
        guard try context.fetch(inProgress).isEmpty else {
            throw KASANEBackupImportError.workoutInProgress
        }

        try context.transaction {
            for workout in try context.fetch(FetchDescriptor<WorkoutSession>()) {
                context.delete(workout)
            }
            for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
                context.delete(exercise)
            }

            var exercisesByID: [UUID: Exercise] = [:]
            for value in backup.exercises {
                let exercise = Exercise(
                    id: value.id,
                    name: value.name,
                    primaryBodyPart: BodyPart(rawValue: value.primaryBodyPart) ?? .other,
                    isArchived: value.isArchived
                )
                exercise.primaryBodyPart = value.primaryBodyPart
                context.insert(exercise)
                exercisesByID[value.id] = exercise
            }
            for workoutValue in backup.workouts {
                let workout = WorkoutSession(
                    id: workoutValue.id,
                    startedAt: workoutValue.startedAt,
                    endedAt: workoutValue.endedAt,
                    note: workoutValue.note
                )
                context.insert(workout)
                for entryValue in workoutValue.exerciseEntries {
                    let constructionExercise =
                        entryValue.exerciseID.flatMap { exercisesByID[$0] }
                        ?? Exercise(name: "", primaryBodyPart: .other)
                    let entry = ExerciseEntry(
                        id: entryValue.id,
                        workoutSession: workout,
                        exercise: constructionExercise,
                        order: entryValue.order
                    )
                    entry.exercise = entryValue.exerciseID.flatMap { exercisesByID[$0] }
                    entry.exerciseNameSnapshot = entryValue.exerciseNameSnapshot
                    entry.primaryBodyPartSnapshot = entryValue.primaryBodyPartSnapshot
                    context.insert(entry)
                    for setValue in entryValue.sets {
                        context.insert(
                            SetEntry(
                                id: setValue.id,
                                exerciseEntry: entry,
                                order: setValue.order,
                                weightKg: setValue.weightKg,
                                reps: setValue.reps,
                                isWarmup: setValue.isWarmup
                            )
                        )
                    }
                }
            }
            try beforeCommit(context)
        }
    }
}

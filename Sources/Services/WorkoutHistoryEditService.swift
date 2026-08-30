import Foundation
import SwiftData

enum WorkoutHistoryEditError: LocalizedError, Equatable {
    case activeWorkout
    case duplicateExercise
    case emptyExercise
    case invalidSet
    case noSets
    case staleDraft

    var errorDescription: String? {
        switch self {
        case .activeWorkout:
            "進行中のワークアウトは履歴から編集できません。"
        case .duplicateExercise:
            "同じ種目を重複して追加できません。"
        case .emptyExercise:
            "セットがない種目は保存できません。"
        case .invalidSet:
            WorkoutSetError.invalidValues.errorDescription
        case .noSets:
            "記録されたセットがないワークアウトは保存できません。"
        case .staleDraft:
            "ワークアウトが別の操作で変更されました。詳細画面から編集し直してください。"
        }
    }
}

@MainActor
struct WorkoutHistoryEditService {
    private struct OriginalSetState {
        let entry: SetEntry
        let order: Int
        let weightKg: Double
        let reps: Int
        let isWarmup: Bool
    }

    private struct OriginalExerciseState {
        let entry: ExerciseEntry
        let order: Int
        let sets: [OriginalSetState]
    }

    private let context: ModelContext
    private let saveChanges: () throws -> Void

    init(context: ModelContext, save: (() throws -> Void)? = nil) {
        self.context = context
        saveChanges = save ?? { try context.save() }
    }

    func save(_ draft: WorkoutHistoryEditDraft, to session: WorkoutSession) throws {
        guard session.endedAt != nil else { throw WorkoutHistoryEditError.activeWorkout }
        guard draft.sessionID == session.id else { throw WorkoutHistoryEditError.staleDraft }

        let valuesBySetID = try validatedValues(in: draft)
        let originalStartedAt = session.startedAt
        let originalEndedAt = session.endedAt
        let originalExercises = session.exerciseEntries
            .sorted { $0.order < $1.order }
            .map { entry in
                OriginalExerciseState(
                    entry: entry,
                    order: entry.order,
                    sets: entry.setEntries.map { setEntry in
                        OriginalSetState(
                            entry: setEntry,
                            order: setEntry.order,
                            weightKg: setEntry.weightKg,
                            reps: setEntry.reps,
                            isWarmup: setEntry.isWarmup
                        )
                    }
                )
            }
        let originalEntryByID = Dictionary(uniqueKeysWithValues: originalExercises.map { ($0.entry.id, $0.entry) })
        let originalSetByID = Dictionary(
            uniqueKeysWithValues: originalExercises.flatMap(\.sets).map { ($0.entry.id, $0.entry) }
        )
        let draftEntryIDs = Set(draft.exercises.map(\.id))
        let draftSetIDs = Set(draft.exercises.flatMap(\.sets).map(\.id))

        do {
            for original in originalExercises where !draftEntryIDs.contains(original.entry.id) {
                context.delete(original.entry)
            }

            let exercisesByID = try fetchExercises(for: draft)
            for (exerciseOrder, exerciseDraft) in draft.exercises.enumerated() {
                let entry: ExerciseEntry
                if let existing = originalEntryByID[exerciseDraft.id] {
                    entry = existing
                    entry.order = exerciseOrder
                } else {
                    guard
                        let exerciseID = exerciseDraft.exerciseID,
                        let exercise = exercisesByID[exerciseID]
                    else { throw WorkoutHistoryEditError.staleDraft }
                    entry = ExerciseEntry(
                        id: exerciseDraft.id,
                        workoutSession: session,
                        exercise: exercise,
                        order: exerciseOrder
                    )
                    entry.exerciseNameSnapshot = exerciseDraft.exerciseNameSnapshot
                    entry.primaryBodyPartSnapshot = exerciseDraft.primaryBodyPartSnapshot
                    context.insert(entry)
                }

                for existingSet in entry.setEntries where !draftSetIDs.contains(existingSet.id) {
                    context.delete(existingSet)
                }
                for (setOrder, setDraft) in exerciseDraft.sets.enumerated() {
                    guard let values = valuesBySetID[setDraft.id] else {
                        throw WorkoutHistoryEditError.invalidSet
                    }
                    if let existing = originalSetByID[setDraft.id] {
                        guard existing.exerciseEntry?.id == entry.id else {
                            throw WorkoutHistoryEditError.staleDraft
                        }
                        existing.order = setOrder
                        existing.weightKg = values.weight
                        existing.reps = values.reps
                    } else {
                        context.insert(
                            SetEntry(
                                id: setDraft.id,
                                exerciseEntry: entry,
                                order: setOrder,
                                weightKg: values.weight,
                                reps: values.reps,
                                isWarmup: false
                            )
                        )
                    }
                }
            }

            try saveChanges()
        } catch {
            context.rollback()
            session.startedAt = originalStartedAt
            session.endedAt = originalEndedAt
            session.exerciseEntries = originalExercises.map(\.entry)
            for original in originalExercises {
                original.entry.order = original.order
                original.entry.workoutSession = session
                original.entry.setEntries = original.sets.map(\.entry)
                for setState in original.sets {
                    setState.entry.order = setState.order
                    setState.entry.weightKg = setState.weightKg
                    setState.entry.reps = setState.reps
                    setState.entry.isWarmup = setState.isWarmup
                    setState.entry.exerciseEntry = original.entry
                }
            }
            throw error
        }
    }

    private func validatedValues(
        in draft: WorkoutHistoryEditDraft
    ) throws -> [UUID: (weight: Double, reps: Int)] {
        guard !draft.exercises.isEmpty else { throw WorkoutHistoryEditError.noSets }
        guard draft.exercises.allSatisfy({ !$0.sets.isEmpty }) else {
            throw WorkoutHistoryEditError.emptyExercise
        }

        let exerciseIDs = draft.exercises.compactMap(\.exerciseID)
        guard Set(exerciseIDs).count == exerciseIDs.count else {
            throw WorkoutHistoryEditError.duplicateExercise
        }

        var valuesBySetID: [UUID: (weight: Double, reps: Int)] = [:]
        for setDraft in draft.exercises.flatMap(\.sets) {
            guard let values = setDraft.values.values() else {
                throw WorkoutHistoryEditError.invalidSet
            }
            guard valuesBySetID.updateValue(values, forKey: setDraft.id) == nil else {
                throw WorkoutHistoryEditError.staleDraft
            }
        }
        guard !valuesBySetID.isEmpty else { throw WorkoutHistoryEditError.noSets }
        return valuesBySetID
    }

    private func fetchExercises(
        for draft: WorkoutHistoryEditDraft
    ) throws -> [UUID: Exercise] {
        let requiredIDs = Set(draft.exercises.compactMap(\.exerciseID))
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
            .filter { requiredIDs.contains($0.id) }
        return Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }
}

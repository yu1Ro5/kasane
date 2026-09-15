import Foundation
import SwiftData

enum WorkoutQuickInputApplyError: LocalizedError, Equatable {
    case invalidDraft
    case unresolvedExercise
    case duplicateExercise
    case pendingDraft(String)

    var errorDescription: String? {
        switch self {
        case .invalidDraft:
            "重量は0以上かつ小数点以下2桁まで、回数は1以上の整数で入力してください。"
        case .unresolvedExercise:
            "未解決の種目があります。既存の種目を選択してください。"
        case .duplicateExercise:
            "同じ種目が複数含まれています。1つにまとめてください。"
        case .pendingDraft(let name):
            "\(name)には入力中のセットがあります。入力中のセットを確定または削除してから追加してください。"
        }
    }
}

@MainActor
struct WorkoutQuickInputApplyService {
    private let context: ModelContext
    private let save: @MainActor () throws -> Void

    init(context: ModelContext, save: (@MainActor () throws -> Void)? = nil) {
        self.context = context
        self.save = save ?? { try context.save() }
    }

    func apply(
        _ draft: WorkoutQuickInputDraft,
        to session: WorkoutSession,
        exercises: [Exercise],
        draftStore: WorkoutDraftStore
    ) throws {
        let resolvedIDs = draft.exercises.compactMap(\.exerciseID)
        guard resolvedIDs.count == draft.exercises.count else {
            throw WorkoutQuickInputApplyError.unresolvedExercise
        }
        guard Set(resolvedIDs).count == resolvedIDs.count else {
            throw WorkoutQuickInputApplyError.duplicateExercise
        }
        let exerciseByID = exercises.reduce(into: [UUID: Exercise]()) { result, exercise in
            result[exercise.id] = exercise
        }
        for item in draft.exercises {
            guard
                let exerciseID = item.exerciseID,
                let exercise = exerciseByID[exerciseID],
                exercise.isSelectable,
                !item.sets.isEmpty,
                item.sets.allSatisfy({ $0.values.values() != nil })
            else { throw WorkoutQuickInputApplyError.invalidDraft }
            if hasPendingDraft(for: exerciseID, in: session, draftStore: draftStore) {
                throw WorkoutQuickInputApplyError.pendingDraft(exercise.name)
            }
        }

        let originalOrder = WorkoutExerciseService.orderSnapshot(in: session)
        var appliedEntries: [ExerciseEntry] = []
        do {
            for item in draft.exercises {
                guard let exerciseID = item.exerciseID, let exercise = exerciseByID[exerciseID] else {
                    throw WorkoutQuickInputApplyError.unresolvedExercise
                }
                let entry: ExerciseEntry
                if let existing = session.exerciseEntries.first(where: { $0.exercise?.id == exerciseID }) {
                    entry = existing
                } else {
                    entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
                    context.insert(entry)
                }
                appliedEntries.append(entry)
                for set in item.sets {
                    _ = try WorkoutSetService(context: context).insert(draft: set.values, to: entry)
                }
            }
            orderAppliedEntries(appliedEntries, in: session)
            try save()
        } catch {
            context.rollback()
            WorkoutExerciseService.restoreOrder(originalOrder)
            throw error
        }
    }

    func conflictMessage(
        for draft: WorkoutQuickInputDraft,
        in session: WorkoutSession,
        exercises: [Exercise],
        draftStore: WorkoutDraftStore
    ) -> String? {
        let byID = exercises.reduce(into: [UUID: String]()) { result, exercise in
            result[exercise.id] = exercise.name
        }
        for item in draft.exercises {
            guard let id = item.exerciseID, hasPendingDraft(for: id, in: session, draftStore: draftStore) else {
                continue
            }
            return WorkoutQuickInputApplyError.pendingDraft(byID[id] ?? item.sourceName)
                .errorDescription
        }
        return nil
    }

    private func hasPendingDraft(
        for exerciseID: UUID,
        in session: WorkoutSession,
        draftStore: WorkoutDraftStore
    ) -> Bool {
        if !draftStore.pendingDraft(for: exerciseID, in: session.id).isEmpty { return true }
        guard let entry = session.exerciseEntries.first(where: { $0.exercise?.id == exerciseID }) else {
            return false
        }
        return !draftStore.draft(for: entry.id, in: session.id).isEmpty
    }

    private func orderAppliedEntries(_ appliedEntries: [ExerciseEntry], in session: WorkoutSession) {
        let appliedIDs = Set(appliedEntries.map(\.id))
        let remaining = session.exerciseEntries
            .filter { !appliedIDs.contains($0.id) }
            .sorted { $0.order < $1.order }
        for (order, entry) in (appliedEntries + remaining).enumerated() {
            entry.order = order
        }
    }
}

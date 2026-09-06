import Foundation
import SwiftData

/// セットの追加・修正・削除を検証し、変更を即時保存する。
@MainActor
struct WorkoutSetService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func add(draft: SetEntryDraft, to exerciseEntry: ExerciseEntry) throws -> SetEntry {
        let originalOrder = orderSnapshot(for: exerciseEntry)
        let setEntry = try insert(draft: draft, to: exerciseEntry)
        moveExerciseToFront(exerciseEntry)
        do {
            try context.save()
            return setEntry
        } catch {
            context.rollback()
            WorkoutExerciseService.restoreOrder(originalOrder)
            throw error
        }
    }

    /// 検証済みDraftからSetEntryを生成してコンテキストへ追加する。保存は呼び出し側が行う。
    func insert(draft: SetEntryDraft, to exerciseEntry: ExerciseEntry) throws -> SetEntry {
        guard let values = draft.values() else { throw WorkoutSetError.invalidValues }
        let order = (exerciseEntry.setEntries.map(\.order).max() ?? -1) + 1
        let setEntry = SetEntry(
            exerciseEntry: exerciseEntry,
            order: order,
            weightKg: values.weight,
            reps: values.reps,
            isWarmup: false
        )
        context.insert(setEntry)
        return setEntry
    }

    func update(_ setEntry: SetEntry, draft: SetEntryDraft) throws {
        guard let values = draft.values() else { throw WorkoutSetError.invalidValues }
        let originalOrder = setEntry.exerciseEntry.map { orderSnapshot(for: $0) } ?? []
        setEntry.weightKg = values.weight
        setEntry.reps = values.reps
        if let exerciseEntry = setEntry.exerciseEntry {
            moveExerciseToFront(exerciseEntry)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            WorkoutExerciseService.restoreOrder(originalOrder)
            throw error
        }
    }

    func delete(_ setEntry: SetEntry, from exerciseEntry: ExerciseEntry) throws {
        let originalOrder = orderSnapshot(for: exerciseEntry)
        context.delete(setEntry)
        let remaining = exerciseEntry.setEntries.filter { $0.id != setEntry.id }.sorted { $0.order < $1.order }
        for (order, entry) in remaining.enumerated() {
            entry.order = order
        }
        moveExerciseToFront(exerciseEntry)
        do {
            try context.save()
        } catch {
            context.rollback()
            WorkoutExerciseService.restoreOrder(originalOrder)
            throw error
        }
    }

    private func moveExerciseToFront(_ exerciseEntry: ExerciseEntry) {
        guard let session = exerciseEntry.workoutSession, session.endedAt == nil else { return }
        WorkoutExerciseService.moveToFront(exerciseEntry, in: session)
    }

    private func orderSnapshot(
        for exerciseEntry: ExerciseEntry
    ) -> [(entry: ExerciseEntry, order: Int)] {
        guard let session = exerciseEntry.workoutSession, session.endedAt == nil else { return [] }
        return WorkoutExerciseService.orderSnapshot(in: session)
    }
}

enum WorkoutSetError: LocalizedError, Equatable {
    case invalidValues

    var errorDescription: String? {
        "重量は0以上かつ小数点以下2桁まで、回数は1以上の整数で入力してください。"
    }
}

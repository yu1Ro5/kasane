import Foundation
import SwiftData

/// 完了済みWorkoutのDraft検証または一括保存に失敗した理由。
enum WorkoutHistoryEditError: LocalizedError, Equatable {
    /// 進行中Workoutを履歴編集しようとした。
    case activeWorkout
    /// 同じ種目が1つのWorkoutへ重複している。
    case duplicateExercise
    /// セットを持たない種目が含まれている。
    case emptyExercise
    /// 重量または回数が入力規則を満たしていない。
    case invalidSet
    /// Workout全体に有効なセットが存在しない。
    case noSets
    /// Draft作成後に保存対象のWorkoutが変更されている。
    case staleDraft

    /// ユーザーへ表示するローカライズ済みエラーメッセージ。
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

/// 完了済みWorkoutの編集Draftを検証し、SwiftDataへ一括反映するService。
@MainActor
struct WorkoutHistoryEditService {
    /// 保存失敗時に既存セットを復元するための状態。
    private struct OriginalSetState {
        /// 復元対象のSwiftDataモデル。
        let entry: SetEntry
        /// 保存開始前のセット順。
        let order: Int
        /// 保存開始前の重量。
        let weightKg: Double
        /// 保存開始前の回数。
        let reps: Int
        /// 保存開始前のウォームアップ状態。
        let isWarmup: Bool
    }

    /// 保存失敗時に既存種目と配下のセットを復元するための状態。
    private struct OriginalExerciseState {
        /// 復元対象のSwiftDataモデル。
        let entry: ExerciseEntry
        /// 保存開始前の種目順。
        let order: Int
        /// 保存開始前のセット状態。
        let sets: [OriginalSetState]
    }

    /// 編集内容の挿入・更新・削除に使用するSwiftDataコンテキスト。
    private let context: ModelContext
    /// 呼び出し側から差し替え可能な保存処理。
    private let saveChanges: () throws -> Void

    /// Workout履歴編集Serviceを作成する。
    /// - Parameters:
    ///   - context: 編集内容の反映先となるSwiftDataコンテキスト。
    ///   - save: 保存処理を差し替える場合のクロージャ。省略時は`context.save()`を使用する。
    init(context: ModelContext, save: (() throws -> Void)? = nil) {
        self.context = context
        saveChanges = save ?? { try context.save() }
    }

    /// Draftを検証し、完了済みWorkoutへ種目・セットの変更を一括保存する。
    /// - Parameters:
    ///   - draft: 保存する編集Draft。
    ///   - session: 編集対象の完了済みWorkout。
    /// - Throws: 入力が不正な場合、Draftが古い場合、またはSwiftDataの保存に失敗した場合。
    func save(_ draft: WorkoutHistoryEditDraft, to session: WorkoutSession) throws {
        guard session.endedAt != nil else { throw WorkoutHistoryEditError.activeWorkout }
        guard draft.matchesOriginalState(of: session) else {
            throw WorkoutHistoryEditError.staleDraft
        }

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

    /// Draft内の全セットを検証し、保存に使用する数値へ変換する。
    /// - Parameter draft: 検証する編集Draft。
    /// - Returns: セットDraft識別子をキーとする重量・回数。
    /// - Throws: Workoutまたはセットの構造・入力値が保存条件を満たさない場合。
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

    /// 新規種目Draftが参照する種目マスタをSwiftDataから取得する。
    /// - Parameter draft: 種目マスタを必要とする編集Draft。
    /// - Returns: 種目マスタ識別子をキーとする`Exercise`。
    /// - Throws: SwiftDataからの取得に失敗した場合。
    private func fetchExercises(
        for draft: WorkoutHistoryEditDraft
    ) throws -> [UUID: Exercise] {
        let requiredIDs = Set(draft.exercises.compactMap(\.exerciseID))
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
            .filter { requiredIDs.contains($0.id) }
        return Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }
}

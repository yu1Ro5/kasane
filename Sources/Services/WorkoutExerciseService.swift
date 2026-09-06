import Foundation
import SwiftData

enum WorkoutExerciseError: LocalizedError {
    case duplicateExercise

    var errorDescription: String? {
        "この種目はすでに追加されています。"
    }
}

/// 進行中セッションの種目を記録・削除し、変更を即時保存する。
@MainActor
struct WorkoutExerciseService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 未記録種目の最初のセットとExerciseEntryを同一トランザクションで保存する。
    ///
    /// 入力画面を開いただけでは呼び出さず、有効なセットが確定した時点で使用する。
    @discardableResult
    func recordFirstSet(
        draft: SetEntryDraft,
        for exercise: Exercise,
        in session: WorkoutSession
    ) throws -> ExerciseEntry {
        guard !session.exerciseEntries.contains(where: { $0.exercise?.id == exercise.id }) else {
            throw WorkoutExerciseError.duplicateExercise
        }

        guard draft.values() != nil else { throw WorkoutSetError.invalidValues }

        let originalOrder = Self.orderSnapshot(in: session)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        context.insert(entry)
        Self.moveToFront(entry, in: session)
        do {
            _ = try WorkoutSetService(context: context).insert(draft: draft, to: entry)
            try context.save()
            return entry
        } catch {
            context.rollback()
            Self.restoreOrder(originalOrder)
            throw error
        }
    }

    func delete(_ entry: ExerciseEntry, from session: WorkoutSession) throws {
        let originalOrder = Self.orderSnapshot(in: session)
        context.delete(entry)
        let remaining = Self.uniqueEntries(session.exerciseEntries)
            .filter { $0.id != entry.id }
            .sorted { $0.order < $1.order }
        for (order, item) in remaining.enumerated() {
            item.order = order
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            Self.restoreOrder(originalOrder)
            throw error
        }
    }

    /// 指定した種目を先頭へ移し、同一セッション内のorderを0始まりの連番へ正規化する。
    static func moveToFront(_ entry: ExerciseEntry, in session: WorkoutSession) {
        let remaining = uniqueEntries(session.exerciseEntries)
            .filter { $0.id != entry.id }
            .sorted { $0.order < $1.order }
        let orderedEntries = [entry] + remaining

        // 永続化中もorderが一意になるよう、一時的に負数へ退避してから連番を割り当てる。
        for (index, item) in orderedEntries.enumerated() {
            item.order = -(index + 1)
        }
        for (order, item) in orderedEntries.enumerated() {
            item.order = order
        }
    }

    /// 保存失敗時に表示順を復元するため、現在のorderを取得する。
    static func orderSnapshot(in session: WorkoutSession) -> [(entry: ExerciseEntry, order: Int)] {
        uniqueEntries(session.exerciseEntries).map { (entry: $0, order: $0.order) }
    }

    /// `orderSnapshot(in:)`で取得した表示順をモデルへ戻す。
    static func restoreOrder(_ snapshot: [(entry: ExerciseEntry, order: Int)]) {
        snapshot.forEach { $0.entry.order = $0.order }
    }

    /// SwiftDataのRelationshipが再解決中に同じ論理IDを重複して返しても、orderを一度だけ割り当てる。
    private static func uniqueEntries(_ entries: [ExerciseEntry]) -> [ExerciseEntry] {
        var seenIDs = Set<UUID>()
        return entries.filter { seenIDs.insert($0.id).inserted }
    }
}

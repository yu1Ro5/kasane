import Foundation
import SwiftData

enum WorkoutExerciseError: LocalizedError {
    case duplicateExercise

    var errorDescription: String? {
        "この種目はすでに追加されています。"
    }
}

/// 進行中セッションの種目を追加・削除し、変更を即時保存する。
@MainActor
struct WorkoutExerciseService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func add(_ exercise: Exercise, to session: WorkoutSession) throws -> ExerciseEntry {
        guard !session.exerciseEntries.contains(where: { $0.exercise?.id == exercise.id }) else {
            throw WorkoutExerciseError.duplicateExercise
        }

        let order = (session.exerciseEntries.map(\.order).max() ?? -1) + 1
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: order)
        context.insert(entry)
        do {
            try context.save()
            return entry
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(_ entry: ExerciseEntry, from session: WorkoutSession) throws {
        context.delete(entry)
        let remaining = session.exerciseEntries.filter { $0.id != entry.id }.sorted { $0.order < $1.order }
        for (order, item) in remaining.enumerated() {
            item.order = order
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

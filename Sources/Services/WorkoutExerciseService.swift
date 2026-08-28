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

        let existingEntries = session.exerciseEntries.sorted { $0.order < $1.order }
        // Assign unique temporary values before normalizing so no two persisted entries
        // share an order while the existing entries are shifted back.
        for (index, entry) in existingEntries.enumerated() {
            entry.order = -(index + 1)
        }
        for (index, entry) in existingEntries.enumerated() {
            entry.order = index + 1
        }

        let entry = ExerciseEntry(workoutSession: nil, exercise: exercise, order: 0)
        session.exerciseEntries.append(entry)
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
        session.exerciseEntries.removeAll { $0.id == entry.id }
        context.delete(entry)
        let remaining = session.exerciseEntries.sorted { $0.order < $1.order }
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

import SwiftData

/// ExerciseEntryごとの未確定Draftを、入力文字列のまま永続化する。
@MainActor
struct WorkoutDraftService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ draft: SetEntryDraft, to exerciseEntry: ExerciseEntry) throws {
        if draft.isEmpty {
            exerciseEntry.draftWeight = nil
            exerciseEntry.draftReps = nil
        } else {
            exerciseEntry.draftWeight = draft.weight
            exerciseEntry.draftReps = draft.reps
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

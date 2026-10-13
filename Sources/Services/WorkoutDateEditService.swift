import Foundation
import SwiftData

/// 種目・セットに触れず、完了済みWorkoutの日時だけを保存する。
@MainActor
struct WorkoutDateEditService {
    enum EditError: LocalizedError {
        case invalidDates

        var errorDescription: String? {
            "終了日時は開始日時以降にしてください。"
        }
    }

    private let saveChanges: () throws -> Void

    init(context: ModelContext, save: (() throws -> Void)? = nil) {
        saveChanges = save ?? { try context.save() }
    }

    func save(_ draft: WorkoutDateEditDraft, to session: WorkoutSession) throws {
        guard session.endedAt != nil else { throw WorkoutHistoryEditError.activeWorkout }
        guard draft.matchesOriginalState(of: session) else { throw WorkoutHistoryEditError.staleDraft }
        guard draft.validationMessage == nil else { throw EditError.invalidDates }

        let originalStartedAt = session.startedAt
        let originalEndedAt = session.endedAt
        session.startedAt = draft.startedAt
        session.endedAt = draft.endedAt
        do {
            try saveChanges()
        } catch {
            session.startedAt = originalStartedAt
            session.endedAt = originalEndedAt
            throw error
        }
    }
}

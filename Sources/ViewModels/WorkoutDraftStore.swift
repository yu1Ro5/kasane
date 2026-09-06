import Foundation
import Observation

/// アプリ起動中だけ、進行中Workoutの未確定Draftを保持する。
@MainActor
@Observable
final class WorkoutDraftStore {
    /// セッションIDとエントリIDとDraftのマップ
    private var draftsBySessionID: [UUID: [UUID: SetEntryDraft]] = [:]
    /// セッションIDと未記録Exercise IDとDraftのマップ
    private var pendingDraftsBySessionID: [UUID: [UUID: SetEntryDraft]] = [:]

    /// 指定したエントリのDraftを取得する。
    func draft(for entryID: UUID, in sessionID: UUID) -> SetEntryDraft {
        draftsBySessionID[sessionID]?[entryID] ?? SetEntryDraft()
    }

    /// 指定したセッションの全Draftを取得する。
    func drafts(for sessionID: UUID) -> [UUID: SetEntryDraft] {
        draftsBySessionID[sessionID] ?? [:]
    }

    /// ExerciseEntry生成前の種目Draftを取得する。
    func pendingDraft(for exerciseID: UUID, in sessionID: UUID) -> SetEntryDraft {
        pendingDraftsBySessionID[sessionID]?[exerciseID] ?? SetEntryDraft()
    }

    /// 指定したセッションにあるExerciseEntry生成前の全Draftを取得する。
    func pendingDrafts(for sessionID: UUID) -> [UUID: SetEntryDraft] {
        pendingDraftsBySessionID[sessionID] ?? [:]
    }

    /// 指定したエントリのDraftを更新する。
    func update(_ draft: SetEntryDraft, for entryID: UUID, in sessionID: UUID) {
        if draft.isEmpty {
            removeDraft(for: entryID, in: sessionID)
            return
        }
        draftsBySessionID[sessionID, default: [:]][entryID] = draft
    }

    /// 指定したエントリのDraftを削除する。
    func removeDraft(for entryID: UUID, in sessionID: UUID) {
        draftsBySessionID[sessionID]?[entryID] = nil
        if draftsBySessionID[sessionID]?.isEmpty == true {
            draftsBySessionID[sessionID] = nil
        }
    }

    /// ExerciseEntry生成前の種目Draftを更新する。
    func updatePending(_ draft: SetEntryDraft, for exerciseID: UUID, in sessionID: UUID) {
        if draft.isEmpty {
            removePendingDraft(for: exerciseID, in: sessionID)
            return
        }
        pendingDraftsBySessionID[sessionID, default: [:]][exerciseID] = draft
    }

    /// ExerciseEntry生成前の種目Draftを削除する。
    func removePendingDraft(for exerciseID: UUID, in sessionID: UUID) {
        pendingDraftsBySessionID[sessionID]?[exerciseID] = nil
        if pendingDraftsBySessionID[sessionID]?.isEmpty == true {
            pendingDraftsBySessionID[sessionID] = nil
        }
    }

    /// 指定したセッションの全Draftを削除する。
    func removeAllDrafts(in sessionID: UUID) {
        draftsBySessionID[sessionID] = nil
        pendingDraftsBySessionID[sessionID] = nil
    }
}

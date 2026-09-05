import Foundation
import Observation

/// アプリ起動中だけ、進行中Workoutの未確定Draftを保持する。
@MainActor
@Observable
final class WorkoutDraftStore {
    /// セッションIDとエントリIDとDraftのマップ
    private var draftsBySessionID: [UUID: [UUID: SetEntryDraft]] = [:]

    /// 指定したエントリのDraftを取得する。
    func draft(for entryID: UUID, in sessionID: UUID) -> SetEntryDraft {
        draftsBySessionID[sessionID]?[entryID] ?? SetEntryDraft()
    }

    /// 指定したセッションの全Draftを取得する。
    func drafts(for sessionID: UUID) -> [UUID: SetEntryDraft] {
        draftsBySessionID[sessionID] ?? [:]
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

    /// 指定したセッションの全Draftを削除する。
    func removeAllDrafts(in sessionID: UUID) {
        draftsBySessionID[sessionID] = nil
    }
}

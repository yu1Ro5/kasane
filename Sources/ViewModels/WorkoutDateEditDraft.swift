import Foundation

/// 日時編集を保存するまで永続化モデルから分離する。
struct WorkoutDateEditDraft {
    let sessionID: UUID
    private let originalStartedAt: Date
    private let originalEndedAt: Date?
    var startedAt: Date
    var endedAt: Date

    init(session: WorkoutSession) {
        sessionID = session.id
        originalStartedAt = session.startedAt
        originalEndedAt = session.endedAt
        startedAt = session.startedAt
        endedAt = session.endedAt ?? session.startedAt
    }

    var hasChanges: Bool {
        startedAt != originalStartedAt || endedAt != originalEndedAt
    }

    var validationMessage: String? {
        endedAt < startedAt ? "終了日時は開始日時以降にしてください。" : nil
    }

    var durationText: String {
        guard validationMessage == nil else { return "--" }
        let totalMinutes = Int(endedAt.timeIntervalSince(startedAt) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

    func matchesOriginalState(of session: WorkoutSession) -> Bool {
        session.id == sessionID
            && session.startedAt == originalStartedAt
            && session.endedAt == originalEndedAt
    }
}

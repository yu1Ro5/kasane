import Foundation
import SwiftData

/// 進行中のワークアウトのライフサイクルを管理する。
@MainActor
struct WorkoutSessionService {
    private let context: ModelContext
    private let now: () -> Date

    init(context: ModelContext, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.now = now
    }

    /// 保存済みの進行中セッションを返す。複数存在する場合は最も古い1件を採用する。
    func activeSession() throws -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\WorkoutSession.startedAt)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 進行中セッションがあれば再利用し、なければ作成して即時保存する。
    func startOrResume() throws -> WorkoutSession {
        if let session = try activeSession() {
            return session
        }

        let session = WorkoutSession(startedAt: now(), endedAt: nil, note: nil)
        context.insert(session)
        do {
            try context.save()
            return session
        } catch {
            context.rollback()
            throw error
        }
    }

    /// セッションを破棄し、削除を即時保存する。
    func discard(_ session: WorkoutSession) throws {
        context.delete(session)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

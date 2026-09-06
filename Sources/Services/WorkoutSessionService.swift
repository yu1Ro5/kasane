import Foundation
import SwiftData

/// 保存に成功したワークアウトの完了画面へ渡す集計結果。
struct WorkoutCompletionSummary: Equatable, Hashable {
    /// ワークアウトの開始日時。
    let startedAt: Date
    /// ワークアウトの終了日時。
    let endedAt: Date
    /// 保存済みセットを1件以上持つ種目数。
    let exerciseCount: Int
    /// ワークアウト全体の保存済みセット数。
    let setCount: Int

    /// 開始日時から終了日時までの経過秒数。時計の逆行時は0秒として扱う。
    var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

/// 進行中のワークアウトのライフサイクルを管理する。
@MainActor
struct WorkoutSessionService {
    private let context: ModelContext
    private let now: () -> Date
    private let save: () throws -> Void

    /// 永続化コンテキストと終了日時を供給するクロージャーからサービスを生成する。
    init(
        context: ModelContext,
        now: @escaping () -> Date = Date.init,
        save: (() throws -> Void)? = nil
    ) {
        self.context = context
        self.now = now
        self.save = save ?? { try context.save() }
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
            try save()
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
            try save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 保存済みセットを持つ種目だけを残し、セッションを終了して即時保存する。
    func finish(
        _ session: WorkoutSession,
        drafts: [UUID: SetEntryDraft] = [:]
    ) throws -> WorkoutCompletionSummary {
        guard session.endedAt == nil else { throw WorkoutSessionError.alreadyFinished }

        let setService = WorkoutSetService(context: context)
        do {
            for entry in session.exerciseEntries.sorted(by: { $0.order < $1.order }) {
                if let draft = drafts[entry.id], !draft.isEmpty {
                    _ = try setService.insert(draft: draft, to: entry)
                }
            }
        } catch {
            context.rollback()
            throw error
        }

        let completedAt = now()
        let completedEntries = session.exerciseEntries
            .filter { !$0.setEntries.isEmpty }
            .sorted { $0.order < $1.order }
        guard !completedEntries.isEmpty else { throw WorkoutSessionError.noSavedSets }

        for entry in session.exerciseEntries where entry.setEntries.isEmpty {
            context.delete(entry)
        }
        for (order, entry) in completedEntries.enumerated() {
            entry.order = order
        }
        session.endedAt = completedAt

        do {
            try save()
        } catch {
            context.rollback()
            // SwiftDataのrollback後も、呼び出し元が保持するモデルには代入値が残る場合がある。
            // 保存に失敗したWorkoutを進行中として扱えるよう、終了日時を明示的に戻す。
            session.endedAt = nil
            throw error
        }

        return WorkoutCompletionSummary(
            startedAt: session.startedAt,
            endedAt: completedAt,
            exerciseCount: completedEntries.count,
            setCount: completedEntries.reduce(0) { $0 + $1.setEntries.count }
        )
    }
}

/// ワークアウトセッションのライフサイクル操作で発生するドメインエラー。
enum WorkoutSessionError: LocalizedError, Equatable {
    /// 保存済みセットがなく、完了済みセッションとして保存できない。
    case noSavedSets
    /// すでに終了済みのセッションに対する重複終了操作。
    case alreadyFinished

    /// ユーザーへ表示するエラー内容。
    var errorDescription: String? {
        switch self {
        case .noSavedSets:
            "記録されたセットがありません。"
        case .alreadyFinished:
            "このワークアウトはすでに終了しています。"
        }
    }
}

import Foundation

/// Workout記録から都度算出する当月のサマリー。派生データは永続化しない。
struct OverviewStats {
    /// 同じExerciseを含むWorkout数。表示名は最新の実施記録のsnapshotを使う。
    struct ExerciseFrequency: Identifiable {
        let id: UUID
        let name: String
        let workoutCount: Int
    }

    /// 集計対象月の開始日時。
    let month: Date
    /// 当月に開始した完了済みWorkout数。
    let workoutCount: Int
    /// 当月Workoutの開始から終了までの合計時間。
    let duration: TimeInterval
    /// 当月Workoutの開始日の重複を除いた日数。
    let activeDayCount: Int
    /// 当月Workout数の多い順に並べた最大3種目。
    let frequentExercises: [ExerciseFrequency]
    /// 対象月を問わず完了済みWorkoutが存在するか。
    let hasCompletedWorkouts: Bool

    /// 開始日時が当月内の完了済みWorkoutを集計する。種目はWorkout内で重複排除する。
    /// 同数時は名称、Exercise IDの順で固定し、参照先を失った種目は頻度から除外する。
    init(sessions: [WorkoutSession], entries: [ExerciseEntry], now: Date, calendar: Calendar) {
        let completed = sessions.filter { $0.endedAt != nil }
        hasCompletedWorkouts = !completed.isEmpty
        let interval = calendar.dateInterval(of: .month, for: now)
        month = interval?.start ?? now
        let included = completed.filter { session in
            guard let interval else { return false }
            return session.startedAt >= interval.start && session.startedAt < interval.end
        }
        workoutCount = included.count
        duration = included.reduce(0) { total, session in
            total + max(session.endedAt?.timeIntervalSince(session.startedAt) ?? 0, 0)
        }
        activeDayCount = Set(included.map { calendar.startOfDay(for: $0.startedAt) }).count
        let includedSessionIDs = Set(included.map(\.id))
        let orderedEntries = entries.filter {
            guard let id = $0.workoutSession?.id else { return false }
            return includedSessionIDs.contains(id) && $0.exercise != nil
        }.sorted { lhs, rhs in
            let left = lhs.workoutSession?.startedAt ?? .distantPast
            let right = rhs.workoutSession?.startedAt ?? .distantPast
            if left != right { return left > right }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        var names: [UUID: String] = [:]
        var workouts: [UUID: Set<UUID>] = [:]
        for entry in orderedEntries {
            guard let exerciseID = entry.exercise?.id, let sessionID = entry.workoutSession?.id else {
                continue
            }
            if names[exerciseID] == nil { names[exerciseID] = entry.exerciseNameSnapshot }
            workouts[exerciseID, default: []].insert(sessionID)
        }
        frequentExercises = workouts.map { id, sessions in
            ExerciseFrequency(id: id, name: names[id] ?? "", workoutCount: sessions.count)
        }.sorted {
            if $0.workoutCount != $1.workoutCount { return $0.workoutCount > $1.workoutCount }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.id.uuidString < $1.id.uuidString
        }.prefix(3).map { $0 }
    }

    /// 合計秒数を分単位で切り捨てる。1分未満は0分と区別する。
    var durationText: String {
        if duration > 0 && duration < 60 { return "1分未満" }
        let minutes = Int(duration / 60)
        return minutes >= 60 ? "\(minutes / 60)時間\(minutes % 60)分" : "\(minutes)分"
    }
}

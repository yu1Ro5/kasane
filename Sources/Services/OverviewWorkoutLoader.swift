import Foundation
import SwiftData

/// Overviewに必要なWorkoutを、表示・集計対象へ限定して取得する。
enum OverviewWorkoutLoader {
    /// Overviewに表示する最近のWorkout件数。
    static let recentWorkoutLimit = 3

    /// 完了日時が新しいWorkoutを最大3件取得し、履歴行で使う種目記録を先読みする。
    static var recentWorkoutDescriptor: FetchDescriptor<WorkoutSession> {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate {
                $0.endedAt != nil
            },
            sortBy: [
                SortDescriptor(\WorkoutSession.endedAt, order: .reverse),
                SortDescriptor(\WorkoutSession.startedAt, order: .reverse),
                SortDescriptor(\WorkoutSession.id, order: .forward),
            ]
        )
        descriptor.fetchLimit = recentWorkoutLimit
        descriptor.relationshipKeyPathsForPrefetching = [
            \WorkoutSession.exerciseEntries
        ]
        return descriptor
    }

    /// 指定日時を含む月に開始した完了済みWorkoutと種目記録を取得する。
    static func monthlyWorkoutDescriptor(
        containing date: Date,
        calendar: Calendar
    ) -> FetchDescriptor<WorkoutSession> {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return FetchDescriptor(predicate: #Predicate { _ in false })
        }
        let monthStart = interval.start
        let nextMonthStart = interval.end
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate {
                $0.endedAt != nil
                    && $0.startedAt >= monthStart
                    && $0.startedAt < nextMonthStart
            },
            sortBy: [
                SortDescriptor(\WorkoutSession.startedAt, order: .reverse),
                SortDescriptor(\WorkoutSession.id, order: .forward),
            ]
        )
        descriptor.relationshipKeyPathsForPrefetching = [
            \WorkoutSession.exerciseEntries
        ]
        return descriptor
    }

    /// 最近の完了済みWorkoutを永続化コンテキストから取得する。
    static func fetchRecentWorkouts(in context: ModelContext) throws -> [WorkoutSession] {
        try context.fetch(recentWorkoutDescriptor)
    }

    /// 指定日時を含む月の完了済みWorkoutを永続化コンテキストから取得する。
    static func fetchMonthlyWorkouts(
        containing date: Date,
        calendar: Calendar,
        in context: ModelContext
    ) throws -> [WorkoutSession] {
        try context.fetch(monthlyWorkoutDescriptor(containing: date, calendar: calendar))
    }
}

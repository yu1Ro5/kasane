import Foundation

/// Display-ready Most Trained content without consulting the current exercise catalog.
struct ReplayMostTrainedPresentation: Equatable {
    static let unavailableMessage = "種目別に振り返れる記録がまだありません"
    static let unavailableDescription = "種目を含むワークアウトが記録されると、ここに表示されます。"

    let title: String
    let exerciseName: String?
    let workoutCountText: String?

    init(stats: YearlyReplayStats) {
        title = "\(stats.year)年にいちばん取り組んだ種目"
        exerciseName = stats.mostTrained?.exerciseName
        workoutCountText = stats.mostTrained.map {
            $0.workoutCount.formatted(.number.locale(Locale(identifier: "ja_JP"))) + "回のワークアウト"
        }
    }
}

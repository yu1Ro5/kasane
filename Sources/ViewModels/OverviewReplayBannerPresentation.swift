import Foundation

/// OverviewのReplay導線を、選択月と切り離して表示するための値。
struct OverviewReplayBannerPresentation: Equatable {
    let year: Int
    let isVisible: Bool

    init(
        workouts: [WorkoutSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        year = calendar.component(.year, from: referenceDate)
        isVisible = workouts.contains { $0.endedAt != nil }
    }

    var title: String {
        "\(year) KASANE Replay"
    }
}

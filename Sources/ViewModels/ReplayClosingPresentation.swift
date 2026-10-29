struct ReplayClosingPresentation: Equatable {
    let year: Int
    let message: String
    let workoutCount: Int

    init(stats: YearlyReplayStats, currentYear: Int) {
        year = stats.year
        message = stats.year == currentYear
            ? "今年も、積み重ねた。"
            : "\(stats.year)年も、積み重ねた。"
        workoutCount = stats.workoutCount
    }
}

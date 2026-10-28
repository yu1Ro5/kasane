import Foundation

/// Display-ready Growth & PR values derived directly from an annual Replay snapshot.
struct ReplayGrowthPresentation: Equatable {
    static let unavailableMessage = "比較できる記録がまだありません"
    static let unavailableDescription = "同じ種目の推定1RMを比較できると、ここに表示されます。"

    let growth: ReplayGrowthContent?
    let personalRecordCountText: String

    init(stats: YearlyReplayStats) {
        growth = stats.biggestGrowth.flatMap(Self.makeGrowth)
        personalRecordCountText = stats.personalRecordCount.formatted(
            .number.locale(Locale(identifier: "ja_JP"))
        ) + "回"
    }

    private static func makeGrowth(_ value: YearlyReplayStats.BiggestGrowth) -> ReplayGrowthContent? {
        guard
            value.baselineEstimatedOneRepMax.isFinite,
            value.baselineEstimatedOneRepMax > 0,
            value.peakEstimatedOneRepMax.isFinite,
            value.peakEstimatedOneRepMax > 0,
            value.growthRate.isFinite,
            value.growthRate > 0
        else { return nil }

        return ReplayGrowthContent(
            exerciseName: value.exerciseName,
            growthRateText: "+\(decimalText(value.growthRate))%",
            estimatedOneRepMaxRangeText: decimalText(value.baselineEstimatedOneRepMax)
                + "kg → "
                + decimalText(value.peakEstimatedOneRepMax)
                + "kg"
        )
    }

    private static func decimalText(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "ja_JP"))
                .precision(.fractionLength(1))
        )
    }
}

import Foundation

/// Display-ready Activity values derived directly from an annual Replay snapshot.
struct ReplayActivityPresentation: Equatable {
    static let longWorkoutMessage = "長時間の記録があります。Workout履歴を確認してください。"

    let totalVolumeText: String
    let totalDurationText: String
    let totalSetCountText: String
    let warningMessage: String?

    init(stats: YearlyReplayStats) {
        totalVolumeText = Self.volumeText(stats.totalVolume)
        totalDurationText = Self.durationText(stats.totalDuration)
        totalSetCountText = Self.setCountText(stats.totalSetCount)
        warningMessage = stats.hasWorkoutLongerThanSixHours ? Self.longWorkoutMessage : nil
    }

    static func volumeText(_ volume: Double) -> String {
        let displayValue = volume.isFinite ? volume : 0
        return displayValue.formatted(
            .number
                .locale(Locale(identifier: "ja_JP"))
                .precision(.fractionLength(0...1))
        ) + "kg"
    }

    static func durationText(_ duration: TimeInterval) -> String {
        guard duration.isFinite, duration > 0 else { return "0分" }

        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case (0, _):
            return "\(minutes)分"
        case (_, 0):
            return "\(hours)時間"
        default:
            return "\(hours)時間\(minutes)分"
        }
    }

    static func setCountText(_ setCount: Int) -> String {
        setCount.formatted(.number.locale(Locale(identifier: "ja_JP"))) + "セット"
    }
}

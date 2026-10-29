import Foundation

/// A non-persistent snapshot of Replay metrics for one calendar year.
struct YearlyReplayStats: Equatable {
    struct MostTrained: Equatable {
        let exerciseID: UUID
        let exerciseName: String
        let workoutCount: Int
        let setCount: Int
    }

    struct BiggestGrowth: Equatable {
        let exerciseID: UUID
        let exerciseName: String
        let baselineEstimatedOneRepMax: Double
        let peakEstimatedOneRepMax: Double
        let growthRate: Double

        var absoluteGrowth: Double {
            peakEstimatedOneRepMax - baselineEstimatedOneRepMax
        }
    }

    let year: Int
    let workoutCount: Int
    let totalVolume: Double
    let totalDuration: TimeInterval
    let totalSetCount: Int
    let hasWorkoutLongerThanSixHours: Bool
    let mostTrained: MostTrained?
    let biggestGrowth: BiggestGrowth?
    let personalRecordCount: Int
}

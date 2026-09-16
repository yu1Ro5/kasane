import Foundation

/// A transient maximum-weight personal record detected when a workout finishes.
struct PersonalRecordAchievement: Identifiable, Equatable, Hashable {
    let exerciseID: UUID
    let exerciseName: String
    let previousBest: Double
    let newBest: Double

    var id: UUID { exerciseID }

    var improvement: Double {
        newBest - previousBest
    }
}

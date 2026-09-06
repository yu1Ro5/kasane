import Foundation

struct WorkoutHistoryRowContent {
    let completedAt: Date
    let duration: TimeInterval
    let exerciseNames: [String]

    init?(session: WorkoutSession, exerciseEntries: [ExerciseEntry]? = nil) {
        guard let endedAt = session.endedAt else { return nil }

        completedAt = endedAt
        duration = max(endedAt.timeIntervalSince(session.startedAt), 0)
        exerciseNames = (exerciseEntries ?? session.exerciseEntries)
            .sorted { $0.order < $1.order }
            .map(\.exerciseNameSnapshot)
    }

    var exerciseSummary: String {
        let displayedNames = exerciseNames.prefix(2)
        let remainingCount = exerciseNames.count - displayedNames.count
        let parts = displayedNames + (remainingCount > 0 ? ["ほか\(remainingCount)種目"] : [])
        return parts.joined(separator: "、")
    }

    var durationText: String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

    var exerciseCountText: String {
        "\(exerciseNames.count)種目"
    }
}

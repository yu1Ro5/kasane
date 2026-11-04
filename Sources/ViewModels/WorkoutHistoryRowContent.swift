import Foundation

struct WorkoutHistoryRowContent {
    let startedAt: Date
    let completedAt: Date
    let duration: TimeInterval
    let exerciseNames: [String]
    let bodyPartNames: [String]
    let setCount: Int
    let totalVolume: Double

    init?(session: WorkoutSession, exerciseEntries: [ExerciseEntry]? = nil) {
        guard let endedAt = session.endedAt else { return nil }

        let entries = exerciseEntries ?? session.exerciseEntries
        let orderedEntries = entries.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
        let sets = entries.flatMap(\.setEntries)
        setCount = sets.count
        startedAt = session.startedAt
        completedAt = endedAt
        duration = max(endedAt.timeIntervalSince(session.startedAt), 0)
        exerciseNames = orderedEntries.map(\.exerciseNameSnapshot)
        var seenBodyParts = Set<BodyPart>()
        bodyPartNames = orderedEntries.compactMap { entry in
            let bodyPart = entry.bodyPartSnapshot
            return seenBodyParts.insert(bodyPart).inserted ? bodyPart.displayName : nil
        }
        totalVolume = sets.reduce(0) {
            $0 + max($1.weightKg, 0) * Double(max($1.reps, 0))
        }
    }

    /// 実施順に並べた主対象部位。重複はなく、省略せずすべて表示する。
    var bodyPartSummary: String {
        bodyPartNames.isEmpty ? "部位の記録なし" : bodyPartNames.joined(separator: "・")
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

    var setCountText: String {
        "\(setCount)セット"
    }

    var totalVolumeText: String {
        totalVolume.formatted(.number.precision(.fractionLength(0...1))) + "kg"
    }
}

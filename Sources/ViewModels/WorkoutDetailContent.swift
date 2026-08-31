import Foundation

struct WorkoutDetailContent {
    struct ExerciseContent: Identifiable {
        let id: UUID
        let name: String
        let sets: [SetContent]
    }

    struct SetContent: Identifiable {
        let id: UUID
        let number: Int
        let weightText: String
        let reps: Int
    }

    let startedAt: Date
    let endedAt: Date?
    let duration: TimeInterval?
    let exercises: [ExerciseContent]

    init(
        session: WorkoutSession,
        exerciseEntries: [ExerciseEntry]? = nil,
        setEntries: [SetEntry]? = nil
    ) {
        startedAt = session.startedAt
        endedAt = session.endedAt
        duration = session.endedAt.map { max($0.timeIntervalSince(session.startedAt), 0) }
        exercises = (exerciseEntries ?? session.exerciseEntries)
            .sorted { $0.order < $1.order }
            .map { exerciseEntry in
                let exerciseSets =
                    setEntries.map { entries in
                        entries.filter { $0.exerciseEntry?.id == exerciseEntry.id }
                    } ?? exerciseEntry.setEntries
                return ExerciseContent(
                    id: exerciseEntry.id,
                    name: exerciseEntry.exerciseNameSnapshot,
                    sets:
                        exerciseSets
                        .sorted { $0.order < $1.order }
                        .enumerated()
                        .map { index, setEntry in
                            SetContent(
                                id: setEntry.id,
                                number: index + 1,
                                weightText: WorkoutSetDisplayFormatter.weight(setEntry.weightKg),
                                reps: setEntry.reps
                            )
                        }
                )
            }
    }

    var durationText: String {
        guard let duration else { return "--" }
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

}

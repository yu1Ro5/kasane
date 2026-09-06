import Foundation

enum WorkoutSearch {
    static func sessions(
        matching query: String,
        sessions: [WorkoutSession],
        exerciseEntries: [ExerciseEntry]
    ) -> [WorkoutSession] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        let matchingSessionIDs: Set<UUID> = Set(
            exerciseEntries.compactMap { entry in
                guard entry.exerciseNameSnapshot.localizedStandardContains(normalizedQuery) else {
                    return nil
                }
                return entry.workoutSession?.id
            }
        )

        return
            sessions
            .filter { $0.endedAt != nil && matchingSessionIDs.contains($0.id) }
            .sorted {
                guard let firstEnd = $0.endedAt, let secondEnd = $1.endedAt else { return false }
                return firstEnd > secondEnd
            }
    }
}

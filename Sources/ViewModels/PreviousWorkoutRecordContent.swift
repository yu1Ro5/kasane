import Foundation

/// 進行中のWorkoutで参照する、同一種目の直近完了記録の表示用射影。
///
/// 既存のWorkoutをSource of Truthとし、表示専用データは永続化しない。
struct PreviousWorkoutRecordContent {
    let startedAt: Date
    let exerciseNameSnapshot: String
    let setEntries: [SetEntry]

    static func find(
        for exerciseEntry: ExerciseEntry,
        in currentSession: WorkoutSession,
        sessions: [WorkoutSession]
    ) -> PreviousWorkoutRecordContent? {
        guard let exerciseID = exerciseEntry.exercise?.id else { return nil }

        let match =
            sessions
            .filter { session in
                session.endedAt != nil && session.startedAt < currentSession.startedAt
            }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt { return lhs.startedAt > rhs.startedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .lazy
            .compactMap { session in
                session.exerciseEntries.first { $0.exercise?.id == exerciseID }.map {
                    (session, $0)
                }
            }
            .first

        guard let (previousSession, match) = match else { return nil }
        return PreviousWorkoutRecordContent(
            startedAt: previousSession.startedAt,
            exerciseNameSnapshot: match.exerciseNameSnapshot,
            setEntries: WorkoutSessionContent.setEntries(for: match)
        )
    }
}

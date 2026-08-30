import Foundation

struct WorkoutHistoryEditDraft {
    struct ExerciseDraft: Identifiable, Equatable {
        let id: UUID
        let exerciseID: UUID?
        let exerciseNameSnapshot: String
        let primaryBodyPartSnapshot: String
        var sets: [SetDraft]
    }

    struct SetDraft: Identifiable, Equatable {
        let id: UUID
        var values: SetEntryDraft
        let isWarmup: Bool
    }

    let sessionID: UUID
    private let originalExercises: [ExerciseDraft]
    var exercises: [ExerciseDraft]

    init(session: WorkoutSession) {
        let exercises = session.exerciseEntries
            .sorted { $0.order < $1.order }
            .map { entry in
                ExerciseDraft(
                    id: entry.id,
                    exerciseID: entry.exercise?.id,
                    exerciseNameSnapshot: entry.exerciseNameSnapshot,
                    primaryBodyPartSnapshot: entry.primaryBodyPartSnapshot,
                    sets: entry.setEntries
                        .sorted { $0.order < $1.order }
                        .map { setEntry in
                            SetDraft(
                                id: setEntry.id,
                                values: .savedValues(from: setEntry),
                                isWarmup: setEntry.isWarmup
                            )
                        }
                )
            }

        sessionID = session.id
        originalExercises = exercises
        self.exercises = exercises
    }

    var hasChanges: Bool {
        exercises != originalExercises
    }

    var selectedExerciseIDs: Set<UUID> {
        Set(exercises.compactMap(\.exerciseID))
    }

    mutating func addExercise(_ exercise: Exercise) throws {
        guard !selectedExerciseIDs.contains(exercise.id) else {
            throw WorkoutExerciseError.duplicateExercise
        }
        exercises.append(
            ExerciseDraft(
                id: UUID(),
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                primaryBodyPartSnapshot: exercise.primaryBodyPart,
                sets: []
            )
        )
    }

    mutating func deleteExercise(id: UUID) {
        exercises.removeAll { $0.id == id }
    }

    mutating func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[index].sets.append(
            SetDraft(id: UUID(), values: SetEntryDraft(), isWarmup: false)
        )
    }

    mutating func deleteSet(id: UUID, from exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[index].sets.removeAll { $0.id == id }
    }
}

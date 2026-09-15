import Foundation

struct WorkoutQuickInputDraft: Equatable {
    var exercises: [WorkoutQuickInputExerciseDraft]

    var isEmpty: Bool { exercises.isEmpty }
}

struct WorkoutQuickInputExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var sourceName: String
    var exerciseID: UUID?
    var sets: [WorkoutQuickInputSetDraft]

    init(
        id: UUID = UUID(),
        sourceName: String,
        exerciseID: UUID?,
        sets: [WorkoutQuickInputSetDraft]
    ) {
        self.id = id
        self.sourceName = sourceName
        self.exerciseID = exerciseID
        self.sets = sets
    }
}

struct WorkoutQuickInputSetDraft: Identifiable, Equatable {
    let id: UUID
    var values: SetEntryDraft

    init(id: UUID = UUID(), weight: String, reps: String) {
        self.id = id
        values = SetEntryDraft(weight: weight, reps: reps)
    }
}

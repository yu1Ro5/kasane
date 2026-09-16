import Foundation

enum WorkoutQuickInputSetExpansionError: Error, Equatable {
    case invalidSetCount
    case tooManySets
    case emptySets
    case invalidOverride
    case invalidSetValue
}

struct ExpandedWorkoutQuickInputExercise: Equatable {
    let exerciseName: String
    let sets: [GeneratedWorkoutQuickInputSet]
}

struct WorkoutQuickInputSetExpander {
    static let maximumSetCount = 10

    func expand(
        _ exercise: GeneratedWorkoutQuickInputExercise
    ) throws -> ExpandedWorkoutQuickInputExercise {
        if !exercise.explicitSets.isEmpty {
            guard exercise.explicitSets.count <= Self.maximumSetCount else {
                throw WorkoutQuickInputSetExpansionError.tooManySets
            }
            guard exercise.overrides.isEmpty else {
                throw WorkoutQuickInputSetExpansionError.invalidOverride
            }
            if let count = exercise.setCount, count != exercise.explicitSets.count {
                throw WorkoutQuickInputSetExpansionError.invalidSetCount
            }
            try exercise.explicitSets.forEach(validate)
            return ExpandedWorkoutQuickInputExercise(
                exerciseName: exercise.exerciseName,
                sets: exercise.explicitSets
            )
        }

        guard let count = exercise.setCount else {
            throw WorkoutQuickInputSetExpansionError.emptySets
        }
        guard count > 0 else {
            throw WorkoutQuickInputSetExpansionError.invalidSetCount
        }
        guard count <= Self.maximumSetCount else {
            throw WorkoutQuickInputSetExpansionError.tooManySets
        }
        try validate(.init(weightKg: exercise.defaultWeightKg, reps: exercise.defaultReps))

        var sets = Array(
            repeating: GeneratedWorkoutQuickInputSet(
                weightKg: exercise.defaultWeightKg,
                reps: exercise.defaultReps
            ),
            count: count
        )
        var overriddenSetNumbers = Set<Int>()
        for override in exercise.overrides {
            guard
                (1...count).contains(override.setNumber),
                override.weightKg != nil || override.reps != nil,
                overriddenSetNumbers.insert(override.setNumber).inserted
            else { throw WorkoutQuickInputSetExpansionError.invalidOverride }
            try validate(.init(weightKg: override.weightKg, reps: override.reps))
            let index = override.setNumber - 1
            if let weight = override.weightKg { sets[index].weightKg = weight }
            if let reps = override.reps { sets[index].reps = reps }
        }
        guard !sets.isEmpty else { throw WorkoutQuickInputSetExpansionError.emptySets }
        return ExpandedWorkoutQuickInputExercise(exerciseName: exercise.exerciseName, sets: sets)
    }

    private func validate(_ set: GeneratedWorkoutQuickInputSet) throws {
        guard
            set.weightKg.map({ $0.isFinite && $0 >= 0 }) ?? true,
            set.reps.map({ $0 > 0 }) ?? true
        else { throw WorkoutQuickInputSetExpansionError.invalidSetValue }
    }
}

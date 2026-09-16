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
        let sets: [GeneratedWorkoutQuickInputSet]
        switch exercise.setPattern {
        case .repeated(let repeated):
            sets = try expand(repeated)
        case .explicit(let explicit):
            sets = try validateExplicitSets(explicit.sets)
        }
        return ExpandedWorkoutQuickInputExercise(exerciseName: exercise.exerciseName, sets: sets)
    }

    private func expand(
        _ repeated: GeneratedRepeatedWorkoutSets
    ) throws -> [GeneratedWorkoutQuickInputSet] {
        guard repeated.setCount > 0 else {
            throw WorkoutQuickInputSetExpansionError.invalidSetCount
        }
        guard repeated.setCount <= Self.maximumSetCount else {
            throw WorkoutQuickInputSetExpansionError.tooManySets
        }
        try validate(.init(weightKg: repeated.defaultWeightKg, reps: repeated.defaultReps))

        var sets = Array(
            repeating: GeneratedWorkoutQuickInputSet(
                weightKg: repeated.defaultWeightKg,
                reps: repeated.defaultReps
            ),
            count: repeated.setCount
        )
        var overriddenSetNumbers = Set<Int>()
        for override in repeated.overrides {
            guard
                (1...repeated.setCount).contains(override.setNumber),
                override.weightKg != nil || override.reps != nil,
                overriddenSetNumbers.insert(override.setNumber).inserted
            else { throw WorkoutQuickInputSetExpansionError.invalidOverride }
            try validate(.init(weightKg: override.weightKg, reps: override.reps))
            let index = override.setNumber - 1
            if let weight = override.weightKg { sets[index].weightKg = weight }
            if let reps = override.reps { sets[index].reps = reps }
        }
        return sets
    }

    private func validateExplicitSets(
        _ sets: [GeneratedWorkoutQuickInputSet]
    ) throws -> [GeneratedWorkoutQuickInputSet] {
        guard !sets.isEmpty else { throw WorkoutQuickInputSetExpansionError.emptySets }
        guard sets.count <= Self.maximumSetCount else {
            throw WorkoutQuickInputSetExpansionError.tooManySets
        }
        try sets.forEach(validate)
        return sets
    }

    private func validate(_ set: GeneratedWorkoutQuickInputSet) throws {
        guard
            set.weightKg.map({ $0.isFinite && $0 >= 0 }) ?? true,
            set.reps.map({ $0 > 0 }) ?? true
        else { throw WorkoutQuickInputSetExpansionError.invalidSetValue }
    }
}

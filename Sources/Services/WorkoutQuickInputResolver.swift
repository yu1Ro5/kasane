import Foundation

struct WorkoutQuickInputResolver {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func resolve(
        _ generated: GeneratedWorkoutQuickInput,
        against exercises: [Exercise]
    ) -> WorkoutQuickInputDraft {
        let selectable = exercises.filter(\.isSelectable)
        return WorkoutQuickInputDraft(
            exercises: generated.exercises.map { generatedExercise in
                let match = selectable.first {
                    $0.name.compare(
                        generatedExercise.exerciseName,
                        options: [.caseInsensitive, .widthInsensitive],
                        locale: .current
                    ) == .orderedSame
                }
                return WorkoutQuickInputExerciseDraft(
                    sourceName: generatedExercise.exerciseName,
                    exerciseID: match?.id,
                    sets: generatedExercise.sets.map {
                        WorkoutQuickInputSetDraft(
                            weight: $0.weightKg.map(weightText) ?? "",
                            reps: $0.reps.map(String.init) ?? ""
                        )
                    }
                )
            }
        )
    }

    private func weightText(_ weight: Double) -> String {
        WorkoutSetDisplayFormatter.editableWeightValue(weight)
            .replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }
}

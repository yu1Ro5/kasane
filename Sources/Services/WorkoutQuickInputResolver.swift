import Foundation

struct WorkoutQuickInputResolver {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func resolve(
        _ generated: GeneratedWorkoutQuickInput,
        against exercises: [Exercise]
    ) throws -> WorkoutQuickInputDraft {
        let selectable = exercises.filter(\.isSelectable)
        return WorkoutQuickInputDraft(
            exercises: try generated.exercises.map { generatedExercise in
                let expanded = try WorkoutQuickInputSetExpander().expand(generatedExercise)
                let match = resolveExercise(named: expanded.exerciseName, from: selectable)
                return WorkoutQuickInputExerciseDraft(
                    sourceName: expanded.exerciseName,
                    exerciseID: match?.id,
                    sets: expanded.sets.map {
                        WorkoutQuickInputSetDraft(
                            weight: $0.weightKg.map(weightText) ?? "",
                            reps: $0.reps.map(String.init) ?? ""
                        )
                    }
                )
            }
        )
    }

    private func resolveExercise(named name: String, from exercises: [Exercise]) -> Exercise? {
        if let exact = exercises.first(where: { $0.name == name }) { return exact }
        let normalizedName = normalize(name)
        if let normalized = exercises.first(where: { normalize($0.name) == normalizedName }) {
            return normalized
        }
        let aliases = [
            "ラットプル": "ラットプルダウン",
            "アブダクション": "ヒップアブダクション",
            "アダクション": "ヒップアダクション",
        ]
        guard let canonicalName = aliases[normalizedName] else { return nil }
        return exercises.first { normalize($0.name) == normalize(canonicalName) }
    }

    private func normalize(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .widthInsensitive], locale: locale)
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    private func weightText(_ weight: Double) -> String {
        WorkoutSetDisplayFormatter.editableWeightValue(weight)
            .replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }
}

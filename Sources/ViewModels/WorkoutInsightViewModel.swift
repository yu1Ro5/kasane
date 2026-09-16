import Observation

@MainActor
@Observable
final class WorkoutInsightViewModel {
    private(set) var insight: GeneratedWorkoutInsight?
    private(set) var isGenerating = false

    func generate(
        facts: WorkoutInsightFacts,
        using generator: any WorkoutInsightGenerating
    ) async {
        guard facts.isEligibleForGeneration, !isGenerating, insight == nil else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let generated = try await generator.generate(from: facts)
            try Task.checkCancellation()
            insight = generated
        } catch {
            insight = nil
        }
    }
}

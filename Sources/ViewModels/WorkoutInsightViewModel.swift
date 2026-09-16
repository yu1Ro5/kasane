import Observation

@MainActor
@Observable
final class WorkoutInsightViewModel {
    enum State: Equatable {
        case idle
        case generating
        case generated(GeneratedWorkoutInsight)
        case failed
    }

    private(set) var state: State = .idle

    var insight: GeneratedWorkoutInsight? {
        guard case .generated(let insight) = state else { return nil }
        return insight
    }

    func generate(
        facts: WorkoutInsightFacts,
        using generator: any WorkoutInsightGenerating
    ) async {
        guard state == .idle, facts.isEligibleForGeneration else { return }
        state = .generating
        do {
            let generated = try await generator.generate(from: facts)
            try Task.checkCancellation()
            state = .generated(generated)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed
        }
    }
}

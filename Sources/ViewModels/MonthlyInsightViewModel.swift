import Foundation
import Observation

@MainActor
@Observable
final class MonthlyInsightViewModel {
    enum State: Equatable {
        case idle
        case generating
        case generated(GeneratedMonthlyInsight)
        case failed
    }

    private struct CachedInsight {
        let facts: MonthlyInsightFacts
        let insight: GeneratedMonthlyInsight
    }

    private(set) var state: State = .idle
    private var cache: [CachedInsight] = []
    private var requestID: UUID?
    private var attemptedFacts: MonthlyInsightFacts?

    var insight: GeneratedMonthlyInsight? {
        guard case .generated(let insight) = state else { return nil }
        return insight
    }

    func generate(
        facts: MonthlyInsightFacts,
        using generator: any MonthlyInsightGenerating
    ) async {
        if let cached = cache.first(where: { $0.facts == facts }) {
            requestID = nil
            attemptedFacts = facts
            state = .generated(cached.insight)
            return
        }
        guard facts.isEligibleForGeneration else {
            requestID = nil
            attemptedFacts = facts
            state = .idle
            return
        }
        guard attemptedFacts != facts else { return }

        let currentRequestID = UUID()
        requestID = currentRequestID
        attemptedFacts = facts
        state = .generating
        do {
            let generated = try await generator.generate(from: facts)
            try Task.checkCancellation()
            guard requestID == currentRequestID else { return }
            cache.append(CachedInsight(facts: facts, insight: generated))
            state = .generated(generated)
        } catch {
            guard !Task.isCancelled, requestID == currentRequestID else {
                if requestID == currentRequestID { attemptedFacts = nil }
                return
            }
            state = .failed
        }
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class WorkoutRootViewModel {
    private(set) var activeSession: WorkoutSession?
    private(set) var selectedSession: WorkoutSession?
    var errorMessage: String?

    func refreshActiveSession(fetch: () throws -> WorkoutSession?) {
        do {
            activeSession = try fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openWorkout(startOrResume: () throws -> WorkoutSession) {
        do {
            selectedSession = try startOrResume()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeWorkout() {
        selectedSession = nil
    }
}

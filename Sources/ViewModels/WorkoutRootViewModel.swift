import Foundation
import Observation

@MainActor
@Observable
final class WorkoutRootViewModel {
    private(set) var selectedSession: WorkoutSession?
    private(set) var isStartingNewWorkout = false
    var errorMessage: String?

    func openWorkout(
        activeSession: WorkoutSession?,
        startOrResume: () throws -> WorkoutSession
    ) {
        isStartingNewWorkout = activeSession == nil

        do {
            selectedSession = try startOrResume()
        } catch {
            isStartingNewWorkout = false
            errorMessage = error.localizedDescription
        }
    }

    func closeWorkout() {
        selectedSession = nil
        isStartingNewWorkout = false
    }
}

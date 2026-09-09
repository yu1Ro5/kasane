import Foundation
import Observation

@MainActor
@Observable
final class WorkoutRootViewModel {
    private(set) var activeSession: WorkoutSession?
    var errorMessage: String?

    func refreshActiveSession(fetch: () throws -> WorkoutSession?) {
        do {
            activeSession = try fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startWorkout(startOrResume: () throws -> WorkoutSession) {
        do {
            activeSession = try startOrResume()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

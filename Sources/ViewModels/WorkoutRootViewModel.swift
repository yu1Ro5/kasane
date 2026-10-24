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

    @discardableResult
    func startWorkout(startOrResume: () throws -> WorkoutSession) -> WorkoutSession? {
        guard activeSession == nil else { return activeSession }
        do {
            let session = try startOrResume()
            activeSession = session
            return session
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

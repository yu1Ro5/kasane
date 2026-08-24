import SwiftData
import SwiftUI

@main
struct KASANEApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutExercise.self, WorkoutSet.self])
    }
}

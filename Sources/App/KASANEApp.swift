import SwiftData
import SwiftUI

@main
struct KASANEApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self])
    }
}

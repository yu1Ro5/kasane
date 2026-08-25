import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
            inMemory: true
        )
}

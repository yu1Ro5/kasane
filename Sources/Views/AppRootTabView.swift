import SwiftUI

struct AppRootTabView: View {
    var body: some View {
        TabView {
            Tab("ワークアウト", systemImage: "figure.strengthtraining.traditional") {
                NavigationStack {
                    WorkoutRootView()
                }
            }

            Tab("履歴", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    WorkoutHistoryView()
                }
            }
        }
    }
}

#Preview {
    AppRootTabView()
        .modelContainer(
            for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
            inMemory: true
        )
}

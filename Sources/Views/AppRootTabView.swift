import SwiftUI

struct AppRootTabView: View {
    @State private var draftStore = WorkoutDraftStore()

    var body: some View {
        TabView {
            Tab("概要", systemImage: "square.grid.2x2.fill") {
                NavigationStack {
                    OverviewView()
                }
            }

            Tab("ワークアウト", systemImage: "figure.strengthtraining.traditional") {
                NavigationStack {
                    WorkoutRootView(draftStore: draftStore)
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

import SwiftUI

struct AppRootTabView: View {
    @State private var draftStore = WorkoutDraftStore()
    /// UI ScreenshotでOverviewの対象月を固定するための基準日時。
    var referenceDate: Date? = nil

    var body: some View {
        TabView {
            Tab("概要", systemImage: "square.grid.2x2.fill") {
                NavigationStack {
                    OverviewView(referenceDate: referenceDate)
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

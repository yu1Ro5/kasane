import SwiftUI

struct OverviewView: View {
    var body: some View {
        List {
            NavigationLink {
                WorkoutHistoryView()
            } label: {
                Label("履歴", systemImage: "clock.arrow.circlepath")
            }
        }
        .navigationTitle("概要")
    }
}

#Preview {
    NavigationStack {
        OverviewView()
    }
    .modelContainer(
        for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
        inMemory: true
    )
}

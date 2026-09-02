import SwiftUI

struct OverviewView: View {
    var body: some View {
        List {
            NavigationLink(value: OverviewRoute.history) {
                Label("履歴", systemImage: "clock.arrow.circlepath")
            }
        }
        .navigationTitle("概要")
        .navigationDestination(for: OverviewRoute.self) { route in
            switch route {
            case .history:
                WorkoutHistoryView()
            }
        }
    }
}

private enum OverviewRoute: Hashable {
    case history
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

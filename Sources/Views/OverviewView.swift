import SwiftData
import SwiftUI

struct OverviewView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.endedAt,
        order: .reverse
    ) private var completedSessions: [WorkoutSession]
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]

    var body: some View {
        Group {
            if completedSessions.isEmpty {
                ContentUnavailableView(
                    "ワークアウトがありません",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("完了したワークアウトがここに表示されます。")
                )
            } else {
                List {
                    Section("最近のワークアウト") {
                        ForEach(completedSessions.prefix(3)) { session in
                            if let content = WorkoutHistoryRowContent(
                                session: session,
                                exerciseEntries: observedExerciseEntries.filter {
                                    $0.workoutSession?.id == session.id
                                }
                            ) {
                                NavigationLink(value: OverviewRoute.workoutDetail(session.id)) {
                                    WorkoutHistoryRow(content: content)
                                }
                                .accessibilityIdentifier(
                                    "overview-recent-workout-row-\(session.id.uuidString)"
                                )
                            }
                        }

                        NavigationLink(value: OverviewRoute.history) {
                            Text("すべて表示")
                        }
                    }
                }
            }
        }
        .navigationTitle("概要")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: OverviewRoute.search) {
                    Label("検索", systemImage: "magnifyingglass")
                }
            }
        }
        .navigationDestination(for: OverviewRoute.self) { route in
            switch route {
            case .history:
                WorkoutHistoryView()
            case .search:
                WorkoutSearchView()
            case .workoutDetail(let sessionID):
                if let session = completedSessions.first(where: { $0.id == sessionID }) {
                    WorkoutDetailView(session: session)
                } else {
                    ContentUnavailableView(
                        "ワークアウトを表示できません",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
        }
    }
}

enum OverviewRoute: Hashable {
    case history
    case search
    case workoutDetail(UUID)
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

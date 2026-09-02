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
                                NavigationLink {
                                    WorkoutDetailView(session: session)
                                } label: {
                                    WorkoutHistoryRow(content: content)
                                }
                                .accessibilityIdentifier(
                                    "overview-recent-workout-row-\(session.id.uuidString)"
                                )
                            }
                        }

                        NavigationLink {
                            WorkoutHistoryView()
                        } label: {
                            Text("すべて表示")
                        }
                    }
                }
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

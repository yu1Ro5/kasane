import SwiftData
import SwiftUI

struct WorkoutHistoryView: View {
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
                    "履歴がありません",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("完了したワークアウトがここに表示されます。")
                )
            } else {
                List(completedSessions) { session in
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
                        .accessibilityIdentifier("workout-history-row-\(session.id.uuidString)")
                    }
                }
            }
        }
        .navigationTitle("履歴")
    }
}

private struct WorkoutHistoryRow: View {
    let content: WorkoutHistoryRowContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.completedAt, format: .dateTime.month().day().hour().minute())
                .font(.headline)
            Text(content.exerciseSummary)
            Text("\(content.durationText)・\(content.exerciseCountText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryView()
    }
    .modelContainer(
        for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
        inMemory: true
    )
}

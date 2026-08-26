import SwiftData
import SwiftUI

struct WorkoutHistoryView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.endedAt,
        order: .reverse
    ) private var completedSessions: [WorkoutSession]

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
                    if let content = WorkoutHistoryRowContent(session: session) {
                        WorkoutHistoryRow(content: content)
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

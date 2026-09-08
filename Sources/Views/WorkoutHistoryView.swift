import SwiftData
import SwiftUI

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.endedAt,
        order: .reverse
    ) private var completedSessions: [WorkoutSession]
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]
    @State private var sessionPendingDeletion: WorkoutSession?
    @State private var deletionErrorMessage: String?

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
                        NavigationLink(value: OverviewRoute.workoutDetail(session.id)) {
                            WorkoutHistoryRow(content: content)
                        }
                        .accessibilityIdentifier("workout-history-row-\(session.id.uuidString)")
                        .swipeActions {
                            Button("削除", systemImage: "trash", role: .destructive) {
                                sessionPendingDeletion = session
                            }
                            .accessibilityIdentifier(
                                "delete-workout-\(session.id.uuidString)"
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .confirmationDialog(
            "このワークアウトを削除しますか？",
            isPresented: isConfirmingDeletion,
            presenting: sessionPendingDeletion
        ) { session in
            Button("削除", role: .destructive) { delete(session) }
            Button("キャンセル", role: .cancel) { sessionPendingDeletion = nil }
        } message: { _ in
            Text("この操作は取り消せません。")
        }
        .alert("ワークアウトを削除できませんでした", isPresented: deletionErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(
            get: { sessionPendingDeletion != nil },
            set: { if !$0 { sessionPendingDeletion = nil } }
        )
    }

    private var deletionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )
    }

    private func delete(_ session: WorkoutSession) {
        sessionPendingDeletion = nil
        do {
            try WorkoutSessionService(context: modelContext).deleteCompleted(session)
        } catch {
            deletionErrorMessage = error.localizedDescription
        }
    }
}

struct WorkoutHistoryRow: View {
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

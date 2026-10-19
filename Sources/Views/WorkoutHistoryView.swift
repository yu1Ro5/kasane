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
        let entriesBySession = Dictionary(grouping: observedExerciseEntries) { $0.workoutSession?.id }
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
                        exerciseEntries: entriesBySession[session.id] ?? []
                    ) {
                        NavigationLink(value: OverviewRoute.workoutDetail(session.id)) {
                            WorkoutHistoryRow(content: content)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .accessibilityHint("ワークアウト詳細を表示")
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
                .listStyle(.insetGrouped)
                .listRowSpacing(8)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(content.completedAt, format: .dateTime.month().day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(content.completedAt, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.secondary)
            }
            Text(content.exerciseSummary.isEmpty ? "ワークアウト" : content.exerciseSummary)
                .font(.subheadline.weight(.regular))
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Text(content.durationText)
                    Text(content.exerciseCountText)
                    Text(content.setCountText)
                    Text(content.totalVolumeText)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.durationText)
                    Text(content.exerciseCountText)
                    Text(content.setCountText)
                    Text(content.totalVolumeText)
                }
            }
            .font(.caption.weight(.regular))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(content.completedAt.formatted(.dateTime.year().month().day().hour().minute()))、"
                + "\(content.exerciseSummary)、所要時間\(content.durationText)、"
                + "\(content.exerciseCountText)、\(content.setCountText)、総Volume\(content.totalVolumeText)"
        )
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

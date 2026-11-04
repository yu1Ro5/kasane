import SwiftData
import SwiftUI

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var completedSessions: [WorkoutSession]
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]
    @State private var sessionPendingDeletion: WorkoutSession?
    @State private var deletionErrorMessage: String?

    init() {
        // カレンダーと同じ開始日基準で並べ、同一時刻はID順で安定させる。
        _completedSessions = Query(OverviewWorkoutLoader.dashboardDescriptor)
    }

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
    /// 種目名検索の結果では、検索した種目が一覧から分かるよう従来の要約を残す。
    var showsExerciseSummary = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(content.startedAt, format: .dateTime.month().day())
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text(secondaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(content.durationText, systemImage: "clock")
                        Text(content.exerciseCountText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        Label(content.durationText, systemImage: "clock")
                        Text("・")
                        Text(content.exerciseCountText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(content.startedAt.formatted(.dateTime.year().month().day()))、"
                + "\(secondaryText)、所要時間\(content.durationText)、"
                + "\(content.exerciseCountText)"
        )
    }

    private var secondaryText: String {
        if showsExerciseSummary {
            return content.exerciseSummary.isEmpty ? "ワークアウト" : content.exerciseSummary
        }
        return content.bodyPartSummary
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

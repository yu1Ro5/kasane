import SwiftData
import SwiftUI

struct WorkoutHistoryView: View {
    @Environment(\.calendar) private var calendar
    private let date: Date?
    @Environment(\.modelContext) private var modelContext
    @Query private var completedSessions: [WorkoutSession]
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]
    @State private var sessionPendingDeletion: WorkoutSession?
    @State private var deletionErrorMessage: String?

    init(date: Date? = nil) {
        self.date = date
        // カレンダーと同じ開始日基準で並べ、同一時刻はID順で安定させる。
        _completedSessions = Query(OverviewWorkoutLoader.dashboardDescriptor)
    }

    var body: some View {
        let sessions = OverviewWorkoutLoader.sessions(completedSessions, on: date, calendar: calendar)
        let entriesBySession = Dictionary(grouping: observedExerciseEntries) { $0.workoutSession?.id }
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "履歴がありません",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("完了したワークアウトがここに表示されます。")
                )
            } else {
                List(sessions) { session in
                    if let content = WorkoutHistoryRowContent(
                        session: session,
                        exerciseEntries: entriesBySession[session.id] ?? []
                    ) {
                        NavigationLink(value: OverviewRoute.workoutDetail(session.id)) {
                            WorkoutHistoryRow(content: content)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
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
                .listRowSpacing(6)
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
    /// 種目名検索の結果では、検索した種目が分かるよう従来の要約を残す。
    var showsExerciseSummary = false

    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if showsExerciseSummary || dynamicTypeSize.isAccessibilitySize {
                expandedLayout
            } else {
                compactLayout
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(content.startedAt.formatted(.dateTime.year().month().day()))、"
                + "\(secondaryText)、所要時間\(content.compactDurationText)、"
                + "\(content.exerciseCountText)"
        )
    }

    /// 通常の履歴は1行に固定。日付・時間・種目数を確保し、部位名だけ省略する。
    private var compactLayout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(compactDateText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: true, vertical: false)

            Text(secondaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(content.compactDurationText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)

            Text(content.exerciseCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: 32)
    }

    /// アクセシビリティと種目名検索では、内容を読めるよう縦に広げる。
    private var expandedLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.startedAt, format: .dateTime.month().day())
                .font(.headline)
                .foregroundStyle(.primary)

            Text(secondaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(content.compactDurationText)
                Text("・")
                Text(content.exerciseCountText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var compactDateText: String {
        "\(calendar.component(.month, from: content.startedAt))/\(calendar.component(.day, from: content.startedAt))"
    }

    private var secondaryText: String {
        if showsExerciseSummary {
            return content.exerciseSummary.isEmpty ? "ワークアウト" : content.exerciseSummary
        }
        return content.bodyPartSummary
    }
}

#Preview {
    makeWorkoutHistoryPreview()
}

@MainActor
@ViewBuilder
private func makeWorkoutHistoryPreview() -> some View {
    let container = Result {
        let container = try ModelContainer(
            for: WorkoutSession.self,
            Exercise.self,
            ExerciseEntry.self,
            SetEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try insertWorkoutHistoryPreviewData(into: container.mainContext)
        return container
    }

    switch container {
    case .success(let container):
        NavigationStack {
            WorkoutHistoryView()
        }
        .modelContainer(container)
    case .failure(let error):
        ContentUnavailableView(
            "プレビューを表示できません",
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription)
        )
    }
}

@MainActor
private func insertWorkoutHistoryPreviewData(into context: ModelContext) throws {
    let now = Date.now
    let benchPress = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
    let shoulderPress = Exercise(name: "ショルダープレス", primaryBodyPart: .shoulders)
    let squat = Exercise(name: "スクワット", primaryBodyPart: .legs)
    let deadlift = Exercise(name: "デッドリフト", primaryBodyPart: .back)
    let exercises = [benchPress, shoulderPress, squat, deadlift]

    let sessions = [
        makeWorkoutHistoryPreviewSession(
            startedAt: now.addingTimeInterval(-86_400),
            duration: 3_300,
            exercises: [benchPress, shoulderPress]
        ),
        makeWorkoutHistoryPreviewSession(
            startedAt: now.addingTimeInterval(-4 * 86_400),
            duration: 2_700,
            exercises: [squat]
        ),
        makeWorkoutHistoryPreviewSession(
            startedAt: now.addingTimeInterval(-9 * 86_400),
            duration: 4_200,
            exercises: [deadlift, squat]
        ),
    ]

    exercises.forEach(context.insert)
    sessions.forEach(context.insert)
    try context.save()
}

private func makeWorkoutHistoryPreviewSession(
    startedAt: Date,
    duration: TimeInterval,
    exercises: [Exercise]
) -> WorkoutSession {
    let session = WorkoutSession(
        startedAt: startedAt,
        endedAt: startedAt.addingTimeInterval(duration)
    )
    session.exerciseEntries = exercises.enumerated().map { order, exercise in
        ExerciseEntry(workoutSession: session, exercise: exercise, order: order)
    }
    return session
}

import SwiftData
import SwiftUI

/// 当月の状況と最近の履歴を表示する概要画面。
struct OverviewView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Screenshot等で日時を固定する場合に指定する。通常はTimelineの現在日時を使う。
    var referenceDate: Date? = nil
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.endedAt,
        order: .reverse
    ) private var completedSessions: [WorkoutSession]
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let stats = OverviewStats(
                sessions: completedSessions,
                entries: observedExerciseEntries,
                now: referenceDate ?? timeline.date,
                calendar: calendar
            )
            List {
                Section {
                    monthlySummary(stats)
                } header: {
                    Text(stats.month, format: .dateTime.year().month())
                }

                if !stats.frequentExercises.isEmpty {
                    Section {
                        ForEach(stats.frequentExercises) { exercise in
                            LabeledContent {
                                Text("\(exercise.workoutCount)回")
                                    .monospacedDigit()
                            } label: {
                                Text(exercise.name)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Text("今月よく行う種目")
                    }
                }

                if completedSessions.isEmpty {
                    ContentUnavailableView(
                        "ワークアウトがありません",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("完了したワークアウトがここに表示されます。")
                    )
                    .listRowBackground(Color.clear)
                } else {
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

    /// 数値は同一サマリーにまとめ、アクセシビリティ文字サイズでは縦に配置する。
    private func monthlySummary(_ stats: OverviewStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今月のトレーニング")
                .font(.headline)
            if stats.workoutCount > 0 {
                let layout =
                    dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 24))
                layout {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(stats.workoutCount)")
                            .font(.largeTitle.bold())
                        Text("回")
                            .font(.body)
                    }
                    .accessibilityLabel("ワークアウト \(stats.workoutCount)回")
                    .accessibilityIdentifier("overview-workout-count")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stats.durationText)
                            .font(.title2.bold())
                        Text("トレーニング時間")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("overview-duration")
                }
                Divider()
                Text("活動日数 \(stats.activeDayCount)日")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("overview-active-days")
            } else {
                Text(stats.hasCompletedWorkouts ? "今月の記録はまだありません" : "最初の記録から、少しずつ。")
                    .font(.body)
                Text("完了したワークアウトの回数と時間がここに表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
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

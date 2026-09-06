import SwiftData
import SwiftUI

/// 当月の状況と最近の履歴を表示する概要画面。
struct OverviewView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Screenshot等で日時を固定する場合に指定する。通常はTimelineの現在日時を使う。
    var referenceDate: Date? = nil
    @Query(OverviewWorkoutLoader.recentWorkoutDescriptor) private var completedSessions: [WorkoutSession]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let statsDate = referenceDate ?? timeline.date
            let monthStart = calendar.dateInterval(of: .month, for: statsDate)?.start ?? statsDate
            List {
                OverviewMonthlyStatsSections(
                    referenceDate: statsDate,
                    calendar: calendar,
                    dynamicTypeSize: dynamicTypeSize,
                    hasCompletedWorkouts: !completedSessions.isEmpty
                )
                .id(monthStart)

                if completedSessions.isEmpty {
                    ContentUnavailableView(
                        "ワークアウトがありません",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("完了したワークアウトがここに表示されます。")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("最近のワークアウト") {
                        ForEach(completedSessions) { session in
                            if let content = WorkoutHistoryRowContent(session: session) {
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
                WorkoutDetailDestinationView(sessionID: sessionID)
            }
        }
    }
}

/// 対象月に限定したWorkoutからOverviewの月間統計Sectionを構築する。
private struct OverviewMonthlyStatsSections: View {
    let referenceDate: Date
    let calendar: Calendar
    let dynamicTypeSize: DynamicTypeSize
    let hasCompletedWorkouts: Bool
    @Query private var completedSessions: [WorkoutSession]

    init(
        referenceDate: Date,
        calendar: Calendar,
        dynamicTypeSize: DynamicTypeSize,
        hasCompletedWorkouts: Bool
    ) {
        self.referenceDate = referenceDate
        self.calendar = calendar
        self.dynamicTypeSize = dynamicTypeSize
        self.hasCompletedWorkouts = hasCompletedWorkouts
        _completedSessions = Query(
            OverviewWorkoutLoader.monthlyWorkoutDescriptor(
                containing: referenceDate,
                calendar: calendar
            )
        )
    }

    var body: some View {
        let stats = OverviewStats(
            sessions: completedSessions,
            entries: completedSessions.flatMap(\.exerciseEntries),
            now: referenceDate,
            calendar: calendar,
            hasCompletedWorkouts: hasCompletedWorkouts
        )
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

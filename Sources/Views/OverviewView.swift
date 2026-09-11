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
                    Section {
                        ForEach(completedSessions) { session in
                            if let content = WorkoutHistoryRowContent(session: session) {
                                NavigationLink(value: OverviewRoute.workoutDetail(session.id)) {
                                    WorkoutHistoryRow(content: content)
                                        .padding(.vertical, 6)
                                }
                                .accessibilityIdentifier(
                                    "overview-recent-workout-row-\(session.id.uuidString)"
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                        .padding(.vertical, 4)
                                )
                            }
                        }
                    } header: {
                        HStack {
                            Text("最近のワークアウト")
                            Spacer()
                            NavigationLink(value: OverviewRoute.history) {
                                HStack(spacing: 3) {
                                    Text("すべて表示")
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.bold())
                                }
                                .font(.subheadline)
                                .textCase(nil)
                            }
                        }
                    }
                }
            }
            .listSectionSpacing(20)
        }
        .navigationTitle("概要")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: OverviewRoute.about) {
                    Label("KASANEについて", systemImage: "info.circle")
                }
                .accessibilityLabel("KASANEについて")

                NavigationLink(value: OverviewRoute.search) {
                    Label("検索", systemImage: "magnifyingglass")
                }
            }
        }
        .navigationDestination(for: OverviewRoute.self) { route in
            switch route {
            case .about:
                AboutView()
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
            OverviewHeroCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }

        Section {
            monthlySummary(stats)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text(stats.month, format: .dateTime.year().month())
        }

        if !stats.frequentExercises.isEmpty {
            Section {
                VStack(spacing: 0) {
                    ForEach(Array(stats.frequentExercises.enumerated()), id: \.element.id) {
                        index, exercise in
                        OverviewFrequentExerciseRow(
                            name: exercise.name,
                            workoutCount: exercise.workoutCount
                        )
                        if index < stats.frequentExercises.count - 1 {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                OverviewStatCard(
                    title: "ワークアウト",
                    value: "\(stats.workoutCount)",
                    accessibilityValue: "\(stats.workoutCount)回",
                    systemImage: "dumbbell.fill",
                    identifier: "overview-workout-count"
                )
                OverviewStatCard(
                    title: "合計時間",
                    value: stats.durationText,
                    accessibilityValue: stats.durationText,
                    systemImage: "clock.fill",
                    identifier: "overview-duration"
                )
                OverviewStatCard(
                    title: "活動日数",
                    value: "\(stats.activeDayCount)",
                    accessibilityValue: "\(stats.activeDayCount)日",
                    systemImage: "calendar",
                    identifier: "overview-active-days"
                )
            }
            if stats.workoutCount == 0 {
                Divider()
                Text(stats.hasCompletedWorkouts ? "今月の記録はまだありません" : "最初の記録から、少しずつ。")
                    .font(.body)
                Text("完了したワークアウトの回数と時間がここに表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OverviewHeroCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("積み重ねが、\n今日の自信になる。")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("少しずつでも、続けることが未来の自分をつくる。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .padding(20)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct OverviewStatCard: View {
    let title: String
    let value: String
    let accessibilityValue: String
    let systemImage: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .accessibilityLabel("\(title) \(accessibilityValue)")
                .accessibilityIdentifier(identifier)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OverviewFrequentExerciseRow: View {
    let name: String
    let workoutCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(name)
                .font(.body.weight(.medium))
            Spacer(minLength: 12)
            Text("\(workoutCount)回")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

enum OverviewRoute: Hashable {
    case about
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

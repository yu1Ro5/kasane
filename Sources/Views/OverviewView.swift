import SwiftData
import SwiftUI

/// 選択月の積み重ねと最近の履歴を表示する月間ダッシュボード。
struct OverviewView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let referenceDate: Date
    private let insightGenerator: any MonthlyInsightGenerating
    @State private var selectedMonth: Date
    @State private var insightViewModel = MonthlyInsightViewModel()
    @Query private var completedSessions: [WorkoutSession]
    @Query private var exerciseOverviewEntries: [ExerciseEntry]

    init(
        referenceDate: Date? = nil,
        insightGenerator: any MonthlyInsightGenerating = AppleIntelligenceMonthlyInsightGenerator()
    ) {
        let date = referenceDate ?? Date()
        self.referenceDate = date
        self.insightGenerator = insightGenerator
        _selectedMonth = State(initialValue: Calendar.current.dateInterval(of: .month, for: date)?.start ?? date)
        _completedSessions = Query(OverviewWorkoutLoader.dashboardDescriptor(through: date))
        _exerciseOverviewEntries = Query(OverviewWorkoutLoader.exerciseOverviewEntryDescriptor)
    }

    var body: some View {
        let stats = OverviewStats(
            sessions: completedSessions,
            now: selectedMonth,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let insightFacts = MonthlyInsightFactsBuilder.build(
            stats: stats,
            sessions: completedSessions,
            calendar: calendar
        )
        let exerciseCardContents = ExerciseOverviewCardBuilder.build(entries: exerciseOverviewEntries)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                brandHeader
                VStack(alignment: .leading, spacing: 6) {
                    Text("概要")
                        .font(.largeTitle.bold())
                    monthSelector
                }
                OverviewHeroCard(stats: stats, usesCompactLayout: dynamicTypeSize.isAccessibilitySize)
                if let insight = insightViewModel.insight {
                    MonthlyInsightCard(insight: insight)
                }
                OverviewCalendarCard(
                    stats: stats, selectedMonth: selectedMonth, referenceDate: referenceDate, calendar: calendar)
                if stats.personalRecord != nil || stats.improvement != nil {
                    highlights(stats)
                }
                recentWorkouts
                if !exerciseCardContents.isEmpty {
                    exerciseRecords(exerciseCardContents)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("概要")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: OverviewRoute.about) {
                    Label("KASANEについて", systemImage: "info.circle")
                }
                NavigationLink(value: OverviewRoute.search) {
                    Label("検索", systemImage: "magnifyingglass")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: insightFacts) {
            await insightViewModel.generate(facts: insightFacts, using: insightGenerator)
        }
        .navigationDestination(for: OverviewRoute.self) { route in
            switch route {
            case .about: AboutView()
            case .history: WorkoutHistoryView()
            case .search: WorkoutSearchView()
            case .workoutDetail(let id): WorkoutDetailDestinationView(sessionID: id)
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                Image(systemName: "mountain.2.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                Image(systemName: "triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .offset(x: 4, y: -3)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("K A S A N E")
                    .font(.headline.weight(.medium))
                Text("今日の積み重ねが、明日をつくる")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var monthSelector: some View {
        Menu {
            ForEach(selectableMonths, id: \.self) { month in
                Button {
                    selectedMonth = month
                } label: {
                    if calendar.isDate(month, equalTo: selectedMonth, toGranularity: .month) {
                        Label(month.formatted(.dateTime.year().month()), systemImage: "checkmark")
                    } else {
                        Text(month, format: .dateTime.year().month())
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(selectedMonth, format: .dateTime.year().month())
                    .font(.title3.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("表示する月")
        .accessibilityValue(selectedMonth.formatted(.dateTime.year().month()))
        .accessibilityIdentifier("overview-month-selector")
    }

    private var selectableMonths: [Date] {
        let current = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        let oldestDate = completedSessions.last?.startedAt ?? current
        let oldest = calendar.dateInterval(of: .month, for: oldestDate)?.start ?? current
        var result: [Date] = []
        var month = current
        while month >= oldest {
            result.append(month)
            guard let previous = calendar.date(byAdding: .month, value: -1, to: month) else { break }
            month = previous
        }
        return result
    }

    @ViewBuilder
    private func highlights(_ stats: OverviewStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今月のハイライト")
                .font(.title3.bold())
            let columns =
                dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                if let record = stats.personalRecord {
                    OverviewHighlightCard(highlight: record)
                        .accessibilityIdentifier("overview-highlight-pr")
                }
                if let improvement = stats.improvement {
                    OverviewHighlightCard(highlight: improvement)
                        .accessibilityIdentifier("overview-highlight-improvement")
                }
            }
        }
    }

    private var recentWorkouts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近のワークアウト")
                    .font(.title3.bold())
                Spacer()
                NavigationLink(value: OverviewRoute.history) {
                    HStack(spacing: 4) {
                        Text("すべて見る")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            let sessions = Array(completedSessions.prefix(OverviewWorkoutLoader.recentWorkoutLimit))
            if sessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "dumbbell")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    Text("ワークアウトを完了すると、ここに記録が重なっていきます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal)
                .dashboardCard()
            } else {
                ForEach(sessions) { session in
                    if let content = WorkoutHistoryRowContent(session: session) {
                        NavigationLink(value: OverviewRoute.workoutDetail(session.id)) {
                            OverviewRecentWorkoutCard(content: content)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("overview-recent-workout-row-\(session.id.uuidString)")
                    }
                }
            }
        }
    }

    private func exerciseRecords(_ contents: [ExerciseOverviewCardContent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("種目の記録")
                    .font(.title3.bold())
                Text("これまでに記録した種目")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(contents) { content in
                ExerciseOverviewCard(content: content)
            }
        }
    }
}

private struct MonthlyInsightCard: View {
    let insight: GeneratedMonthlyInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    title
                    Spacer(minLength: 8)
                    attribution
                }
                VStack(alignment: .leading, spacing: 10) {
                    title
                    attribution
                }
            }
            Text(insight.message)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("overview-monthly-insight-card")
    }

    private var title: some View {
        Label("今月のインサイト", systemImage: "sparkles")
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var attribution: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text("Apple Intelligence")
                Text("オンデバイス")
            }
        } icon: {
            Image(systemName: "cpu")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct OverviewHeroCard: View {
    let stats: OverviewStats
    let usesCompactLayout: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("今月の積み重ね")
                    .font(.title2.bold())
                Text("一歩ずつ、確実に。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            let columns =
                usesCompactLayout
                ? [GridItem(.flexible()), GridItem(.flexible())]
                : Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
            LazyVGrid(columns: columns, spacing: 20) {
                HeroMetric(
                    title: "ワークアウト", value: "\(stats.workoutCount)回", spokenValue: "\(stats.workoutCount)回",
                    icon: "dumbbell.fill", identifier: "overview-workout-count")
                HeroMetric(
                    title: "総重量", value: stats.totalVolumeText,
                    spokenValue: "\(stats.totalVolume.formatted(.number.precision(.fractionLength(0...1))))キログラム",
                    icon: "cylinder.split.1x2.fill", identifier: "overview-total-volume")
                HeroMetric(
                    title: "総時間", value: stats.durationText, spokenValue: stats.durationText, icon: "clock.fill",
                    identifier: "overview-duration")
                HeroMetric(
                    title: "継続記録", value: "\(stats.streak)週連続", spokenValue: "\(stats.streak)週連続", icon: "flame.fill",
                    identifier: "overview-streak")
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.43, blue: 0.31), Color(red: 0.02, green: 0.22, blue: 0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                MountainLayers()
                    .fill(.black.opacity(0.16))
                LinearGradient(
                    colors: [.white.opacity(0.14), .clear, .black.opacity(0.16)], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.18), radius: 16, y: 8)
    }
}

private struct MountainLayers: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.61))
        path.addLine(to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.width * 0.77, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.31))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct HeroMetric: View {
    let title: String
    let value: String
    let spokenValue: String
    let icon: String
    let identifier: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.headline)
                .accessibilityHidden(true)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spokenValue)
        .accessibilityIdentifier(identifier)
    }
}

private struct OverviewCalendarCard: View {
    let stats: OverviewStats
    let selectedMonth: Date
    let referenceDate: Date
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedMonth, format: .dateTime.year().month())
                    .font(.headline)
                Spacer()
                Text("今月 \(stats.workoutCount)回のワークアウト")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        CalendarDay(
                            date: day, count: stats.dailyWorkoutCounts[calendar.startOfDay(for: day), default: 0],
                            isToday: isToday(day), calendar: calendar)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            HStack(spacing: 14) {
                Spacer()
                legend("3回以上", opacity: 1)
                legend("2回", opacity: 0.65)
                legend("1回", opacity: 0.32)
                legend("なし", opacity: 0.08)
            }
        }
        .padding(20)
        .dashboardCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview-calendar")
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[offset...] + symbols[..<offset])
    }
    private var calendarDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
            let first = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))
        else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading)
            + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
    }
    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(selectedMonth, equalTo: referenceDate, toGranularity: .month)
            && calendar.isDate(date, inSameDayAs: referenceDate)
    }
    private func legend(_ text: String, opacity: Double) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color.accentColor.opacity(opacity)).frame(width: 9, height: 9)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct CalendarDay: View {
    let date: Date
    let count: Int
    let isToday: Bool
    let calendar: Calendar
    var body: some View {
        VStack(spacing: 3) {
            Text(String(calendar.component(.day, from: date)))
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: isToday ? 34 : 26, height: isToday ? 34 : 26)
                .background(isToday ? Color.accentColor : Color.clear, in: Circle())
            Circle()
                .fill(Color.accentColor.opacity(count >= 3 ? 1 : count == 2 ? 0.65 : count == 1 ? 0.32 : 0))
                .frame(width: 7, height: 7)
        }
        .frame(height: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(.dateTime.month().day()))
        .accessibilityValue(count == 0 ? "ワークアウトなし" : "ワークアウト\(count)回")
    }
}

private struct OverviewHighlightCard: View {
    let highlight: OverviewStats.Highlight
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: highlight.kind == .personalRecord ? "trophy.fill" : "chart.bar.fill")
                    .foregroundStyle(highlight.kind == .personalRecord ? .orange : Color.accentColor)
                Text(highlight.kind == .personalRecord ? "自己ベスト" : "記録の更新")
                    .font(.subheadline.bold())
                    .foregroundStyle(highlight.kind == .personalRecord ? .orange : Color.accentColor)
            }
            Text(highlight.exerciseName).font(.headline).lineLimit(2)
            Text(
                highlight.kind == .personalRecord
                    ? highlight.weight.formatted() + "kg" : "+" + highlight.improvement.formatted() + "kg"
            )
            .font(.title2.bold()).monospacedDigit()
            Text("前回より +\(highlight.improvement.formatted())kg")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .dashboardCard()
        .accessibilityElement(children: .combine)
    }
}

private struct OverviewRecentWorkoutCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let content: WorkoutHistoryRowContent
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        workoutIcon
                        title
                        Spacer(minLength: 4)
                        dateAndChevron
                    }
                    VStack(alignment: .leading, spacing: 5) { metadata }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            } else {
                HStack(spacing: 13) {
                    workoutIcon
                    VStack(alignment: .leading, spacing: 6) {
                        title
                        HStack(spacing: 12) { metadata }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    dateAndChevron
                }
                .padding(12)
            }
        }
        .dashboardCard()
    }

    private var workoutIcon: some View {
        Image(systemName: "dumbbell.fill")
            .font(.title3)
            .foregroundStyle(.tint)
            .frame(width: 48, height: 48)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .accessibilityHidden(true)
    }

    private var title: some View {
        Text(content.exerciseSummary.isEmpty ? "ワークアウト" : content.exerciseSummary)
            .font(.headline)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
    }

    @ViewBuilder private var metadata: some View {
        Label(content.durationText, systemImage: "clock")
        Label(content.exerciseCountText, systemImage: "dumbbell")
        Label(content.totalVolumeText, systemImage: "cylinder.split.1x2")
    }

    private var dateAndChevron: some View {
        VStack(alignment: .trailing, spacing: 7) {
            Text(content.completedAt, format: .dateTime.month().day())
                .font(.subheadline).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
    }
}

private struct ExerciseOverviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let content: ExerciseOverviewCardContent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    bestWeight
                        .accessibilityIdentifier("overview-exercise-card-best-\(content.exerciseID.uuidString)")
                    sparkline
                }
            } else {
                HStack(alignment: .bottom, spacing: 18) {
                    bestWeight
                        .accessibilityIdentifier("overview-exercise-card-best-\(content.exerciseID.uuidString)")
                    Spacer(minLength: 8)
                    sparkline
                }
            }
            if content.isLatestPersonalRecord {
                Label("自己ベスト", systemImage: "trophy.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityDescription)
        .accessibilityIdentifier("overview-exercise-card-\(content.exerciseID.uuidString)")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(content.exerciseName)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text("最終実施日 \(content.latestCompletedAt.formatted(.dateTime.month().day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
        }
    }

    private var bestWeight: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("現在のベスト")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(weightText)
                .font(.title2.bold())
                .monospacedDigit()
        }
    }

    @ViewBuilder private var sparkline: some View {
        if content.showsWeightSparkline {
            ExerciseOverviewSparkline(points: content.recentMaxWeightPoints)
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 132,
                    minHeight: 46,
                    maxHeight: 46,
                    alignment: .trailing
                )
                .accessibilityHidden(true)
                .accessibilityIdentifier("overview-exercise-card-chart-\(content.exerciseID.uuidString)")
        }
    }

    private var weightText: String {
        content.showsWeightSparkline
            ? WorkoutSetDisplayFormatter.displayWeight(content.currentBestWeightKg)
            : "自重"
    }

    private var iconName: String {
        switch content.bodyPart {
        case .arms: "figure.strengthtraining.traditional"
        case .back: "figure.strengthtraining.functional"
        case .chest: "figure.strengthtraining.traditional"
        case .core: "figure.core.training"
        case .fullBody: "figure.mixed.cardio"
        case .legs: "figure.run"
        case .shoulders: "figure.strengthtraining.functional"
        case .other: "dumbbell.fill"
        }
    }
}

private struct ExerciseOverviewSparkline: View {
    let points: [ExerciseOverviewPoint]

    var body: some View {
        GeometryReader { geometry in
            let coordinates = coordinates(in: geometry.size)
            ZStack {
                Path { path in
                    guard let first = coordinates.first else { return }
                    path.move(to: first)
                    for point in coordinates.dropFirst() { path.addLine(to: point) }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ForEach(Array(coordinates.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(
                            width: index == coordinates.count - 1 ? 8 : 5,
                            height: index == coordinates.count - 1 ? 8 : 5
                        )
                        .position(point)
                }
            }
        }
    }

    private func coordinates(in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        let weights = points.map(\.maxWeightKg)
        let minimum = weights.min() ?? 0
        let maximum = weights.max() ?? minimum
        let horizontalInset: CGFloat = 4
        let verticalInset: CGFloat = 5
        let availableWidth = max(size.width - horizontalInset * 2, 0)
        let availableHeight = max(size.height - verticalInset * 2, 0)
        return points.enumerated().map { index, point in
            let progress = points.count == 1 ? 0.5 : CGFloat(index) / CGFloat(points.count - 1)
            let normalized = maximum == minimum ? 0.5 : (point.maxWeightKg - minimum) / (maximum - minimum)
            return CGPoint(
                x: horizontalInset + availableWidth * progress,
                y: verticalInset + availableHeight * (1 - normalized)
            )
        }
    }
}

private extension View {
    func dashboardCard() -> some View {
        background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
    }
}

enum OverviewRoute: Hashable { case about, history, search, workoutDetail(UUID) }

#Preview {
    NavigationStack { OverviewView() }
        .modelContainer(for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self], inMemory: true)
}

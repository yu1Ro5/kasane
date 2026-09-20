import Charts
import SwiftData
import SwiftUI

struct ExerciseProgressDestinationView: View {
    let exerciseID: UUID
    @Query private var entries: [ExerciseEntry]

    init(exerciseID: UUID) {
        self.exerciseID = exerciseID
        _entries = Query(OverviewWorkoutLoader.exerciseOverviewEntryDescriptor)
    }

    var body: some View {
        if let stats = ExerciseProgressBuilder.build(exerciseID: exerciseID, entries: entries) {
            ExerciseProgressView(stats: stats)
        } else {
            ContentUnavailableView("種目を表示できません", systemImage: "exclamationmark.triangle")
        }
    }
}

struct ExerciseProgressView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let stats: ExerciseProgressStats
    @State private var selectedMetric = ExerciseProgressMetric.maxWeight

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                Text("種目の成長")
                    .font(.largeTitle.bold())
                if stats.points.isEmpty {
                    emptyState
                } else {
                    currentBestCard
                    metricPicker
                    progressChart
                    summaryCard
                    recentRecords
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stats.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("exercise-progress-screen")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "まだ記録がありません",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("最初の1回から、成長がここに積み重なります。")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }

    private var currentBestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("現在のベスト", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            Text(bestWeightText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
            if let date = stats.personalRecordDate {
                Label(date.formatted(.dateTime.year().month().day()), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("自己ベスト日 \(date.formatted(.dateTime.year().month().day()))")
                    .accessibilityIdentifier("exercise-progress-pr-date")
            }
            if stats.points.count > 1, stats.currentBest == 0 {
                Text("自重での積み重ね")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if let amount = stats.growthAmount, stats.points.count > 1 {
                Text(growthText(amount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amount > 0 ? Color.accentColor : .secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .progressCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exercise-progress-current-best")
    }

    @ViewBuilder private var metricPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("表示する指標", selection: $selectedMetric) {
                ForEach(ExerciseProgressMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("exercise-progress-segment")
        } else {
            Picker("表示する指標", selection: $selectedMetric) {
                ForEach(ExerciseProgressMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("exercise-progress-segment")
        }
    }

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("成長グラフ")
                .font(.title3.bold())
            Chart {
                ForEach(stats.points) { point in
                    LineMark(
                        x: .value("日付", point.completedAt),
                        y: .value(selectedMetric.rawValue, point.value(for: selectedMetric))
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("日付", point.completedAt),
                        y: .value(selectedMetric.rawValue, point.value(for: selectedMetric))
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(point.id == stats.points.last?.id ? 80 : 34)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel()
                }
            }
            .frame(height: 220)
            .accessibilityLabel("\(selectedMetric.rawValue)の成長グラフ")
            .accessibilityValue(chartAccessibilityValue)
            .accessibilityIdentifier("exercise-progress-chart")
        }
        .padding(18)
        .progressCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("成長サマリー")
                .font(.title3.bold())
            summaryRow("初回", value: metricText(stats.firstValue(for: selectedMetric)))
            summaryRow("現在", value: metricText(stats.currentValue(for: selectedMetric)))
            summaryRow("伸び幅", value: changeText(stats.change(for: selectedMetric)))
            summaryRow("実施回数", value: "\(stats.points.count)回")
        }
        .padding(18)
        .progressCard()
        .accessibilityIdentifier("exercise-progress-summary")
    }

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の記録")
                .font(.title3.bold())
            ForEach(stats.recentRecords) { record in
                NavigationLink(value: OverviewRoute.workoutDetail(record.workoutID)) {
                    recentRecordLabel(record)
                        .padding(16)
                        .contentShape(Rectangle())
                        .progressCard()
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("exercise-progress-recent-records")
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func recentRecordLabel(_ record: ExerciseProgressPoint) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                recordDateAndBadge(record)
                HStack {
                    Text(recordWeightText(record))
                        .font(.headline)
                        .monospacedDigit()
                    Spacer()
                    recordChevron
                }
            }
        } else {
            HStack(spacing: 12) {
                recordDateAndBadge(record)
                Spacer()
                Text(recordWeightText(record))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                recordChevron
            }
        }
    }

    private func recordDateAndBadge(_ record: ExerciseProgressPoint) -> some View {
        HStack(spacing: 8) {
            Text(record.completedAt, format: .dateTime.month().day())
            if record.isPersonalRecord {
                Label("自己ベスト", systemImage: "trophy.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var recordChevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private var bestWeightText: String {
        guard let value = stats.currentBest, value > 0 else { return "自重" }
        return WorkoutSetDisplayFormatter.displayWeight(value)
    }

    private func recordWeightText(_ record: ExerciseProgressPoint) -> String {
        let weight =
            record.maxWeightKg > 0
            ? WorkoutSetDisplayFormatter.displayWeight(record.maxWeightKg) : "自重"
        return "\(weight) × \(record.maxWeightReps)"
    }

    private func metricText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        switch selectedMetric {
        case .maxWeight:
            return value > 0 ? WorkoutSetDisplayFormatter.displayWeight(value) : "自重"
        case .volume:
            return "\(WorkoutSetDisplayFormatter.editableWeightValue(value))kg"
        case .reps:
            return "\(Int(value))回"
        }
    }

    private func changeText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        if selectedMetric == .maxWeight, stats.currentBest == 0 { return "--" }
        return signedNumber(value, suffix: selectedMetric == .reps ? "回" : "kg")
    }

    private func signedWeight(_ value: Double) -> String { signedNumber(value, suffix: "kg") }

    private func growthText(_ amount: Double) -> String {
        var text = "初回比 \(signedWeight(amount))"
        if let percentage = stats.growthPercentage {
            text += "（\(signedNumber(percentage, suffix: "%"))）"
        }
        return text
    }

    private func signedNumber(_ value: Double, suffix: String) -> String {
        let number = WorkoutSetDisplayFormatter.editableWeightValue(abs(value))
        let sign = value > 0 ? "+" : value < 0 ? "−" : "±"
        return "\(sign)\(number)\(suffix)"
    }

    private var chartAccessibilityValue: String {
        stats.points.map {
            "\($0.completedAt.formatted(.dateTime.month().day())) \(metricText($0.value(for: selectedMetric)))"
        }.joined(separator: "、")
    }
}

private extension View {
    func progressCard() -> some View {
        background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
    }
}

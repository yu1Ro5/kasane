import SwiftUI

/// Presents the shared full-screen foundation for the five-page yearly Replay.
struct ReplayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var workoutCountFontSize = 72
    @State private var viewModel: ReplayViewModel

    private let workouts: [WorkoutSession]

    init(
        workouts: [WorkoutSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        self.workouts = workouts
        _viewModel = State(
            initialValue: ReplayViewModel(
                workouts: workouts,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    var body: some View {
        ZStack {
            ReplayBackground()

            VStack(spacing: 12) {
                header

                if viewModel.stats.workoutCount == 0 {
                    emptyState
                } else {
                    pageProgress
                    pages
                    if viewModel.selectedPage == .closing {
                        previousButton
                    } else {
                        pageControls
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: ReplayWorkoutInput(workouts: workouts), initial: true) { _, _ in
            viewModel.update(workouts: workouts)
        }
    }

    private var header: some View {
        ZStack {
            yearSelector

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Replayを閉じる", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityIdentifier("replay-close-button")
            }
        }
        .frame(minHeight: 44)
    }

    private var yearSelector: some View {
        Menu {
            ForEach(viewModel.availableYears, id: \.self) { year in
                Button {
                    changeYear(to: year)
                } label: {
                    if year == viewModel.selectedYear {
                        Label("\(year)年", systemImage: "checkmark")
                    } else {
                        Text("\(year)年")
                    }
                }
                .accessibilityValue(year == viewModel.selectedYear ? "選択中" : "")
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(viewModel.selectedYear)")
                    .font(.headline.monospacedDigit())
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(.thinMaterial, in: Capsule())
        }
        .accessibilityLabel("Replayの対象年")
        .accessibilityValue("\(viewModel.selectedYear)年")
        .accessibilityHint("ダブルタップして対象年を変更")
        .accessibilityIdentifier("replay-year-selector")
    }

    private var pageProgress: some View {
        HStack(spacing: 7) {
            ForEach(ReplayPage.allCases) { page in
                Capsule()
                    .fill(page == viewModel.selectedPage ? Color.accentColor : Color.secondary.opacity(0.22))
                    .frame(maxWidth: page == viewModel.selectedPage ? 32 : 18, minHeight: 5, maxHeight: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Replayの進捗")
        .accessibilityValue("5ページ中\(viewModel.pagePosition)ページ、\(viewModel.selectedPage.title)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                moveToNextPage()
            case .decrement:
                moveToPreviousPage()
            @unknown default:
                break
            }
        }
        .accessibilityIdentifier("replay-page-progress")
    }

    private var pages: some View {
        TabView(selection: pageSelection) {
            ReplayIntroPage(stats: viewModel.stats, countFontSize: workoutCountFontSize)
                .tag(ReplayPage.intro)

            ReplayActivityPage(stats: viewModel.stats)
                .tag(ReplayPage.activity)

            ReplayMostTrainedPage(stats: viewModel.stats)
                .tag(ReplayPage.mostTrained)

            ReplayGrowthPage(stats: viewModel.stats)
                .tag(ReplayPage.growthAndPersonalRecords)

            ReplayClosingPage(
                presentation: ReplayClosingPresentation(
                    stats: viewModel.stats,
                    currentYear: viewModel.currentYear
                ),
                replayAction: restartReplay,
                closeAction: { dismiss() }
            )
                .tag(ReplayPage.closing)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .accessibilityIdentifier("replay-pages")
    }

    private var pageControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                previousButton
                nextButton
            }
            VStack(spacing: 10) {
                nextButton
                previousButton
            }
        }
    }

    private var previousButton: some View {
        Button(action: moveToPreviousPage) {
            Label("前へ", systemImage: "chevron.left")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(!viewModel.canGoBack)
        .accessibilityIdentifier("replay-previous-button")
    }

    private var nextButton: some View {
        Button(action: moveToNextPage) {
            Label("次へ", systemImage: "chevron.right")
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("replay-next-button")
    }

    private var emptyState: some View {
        ReplayPageLayout {
            ContentUnavailableView {
                Label("\(viewModel.selectedYear)年のReplayはまだありません", systemImage: "calendar")
            } description: {
                Text("ワークアウトを完了すると、この年の積み重ねを振り返れます。")
            }
        }
        .accessibilityIdentifier("replay-empty-state")
    }

    private var pageSelection: Binding<ReplayPage> {
        Binding(
            get: { viewModel.selectedPage },
            set: { viewModel.showPage($0) }
        )
    }

    private func changeYear(to year: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            viewModel.selectYear(year)
        }
    }

    private func moveToPreviousPage() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            viewModel.showPreviousPage()
        }
    }

    private func moveToNextPage() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            viewModel.showNextPage()
        }
    }

    private func restartReplay() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            viewModel.restart()
        }
    }
}

private struct ReplayIntroPage: View {
    let stats: YearlyReplayStats
    let countFontSize: CGFloat

    var body: some View {
        ReplayPageLayout {
            VStack(spacing: 18) {
                Text("KASANE REPLAY")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.secondary)

                Text("\(stats.year)")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .monospacedDigit()

                VStack(spacing: 4) {
                    Text("\(stats.workoutCount)")
                        .font(.system(size: countFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    Text("完了したワークアウト")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("完了したワークアウト")
                .accessibilityValue("\(stats.workoutCount)回")

                Text("この一年の積み重ねを振り返りましょう")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
            }
            .padding(.vertical, 36)
        }
        .accessibilityIdentifier("replay-intro-page")
    }
}

struct ReplayPageLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct ReplayBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color(uiColor: .systemBackground),
                    Color.accentColor.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 280, height: 280)
                .offset(x: 150, y: -260)

            Circle()
                .fill(Color.secondary.opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: -150, y: 300)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct ReplayWorkoutInput: Equatable {
    struct Workout: Equatable {
        let id: UUID
        let startedAt: Date
        let endedAt: Date?
        let entries: [Entry]
    }

    struct Entry: Equatable {
        let id: UUID
        let exerciseID: UUID?
        let exerciseName: String
        let order: Int
        let sets: [Set]
    }

    struct Set: Equatable {
        let id: UUID
        let order: Int
        let weightKg: Double
        let reps: Int
        let isWarmup: Bool
    }

    let workouts: [Workout]

    init(workouts: [WorkoutSession]) {
        self.workouts = workouts.map { workout in
            Workout(
                id: workout.id,
                startedAt: workout.startedAt,
                endedAt: workout.endedAt,
                entries: workout.exerciseEntries.map { entry in
                    Entry(
                        id: entry.id,
                        exerciseID: entry.exercise?.id,
                        exerciseName: entry.exerciseNameSnapshot,
                        order: entry.order,
                        sets: entry.setEntries.map {
                            Set(
                                id: $0.id,
                                order: $0.order,
                                weightKg: $0.weightKg,
                                reps: $0.reps,
                                isWarmup: $0.isWarmup
                            )
                        }
                    )
                }
            )
        }
    }
}

#Preview("Replay") {
    ReplayView(
        workouts: [
            WorkoutSession(
                startedAt: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 12)) ?? .now,
                endedAt: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 1))
            )
        ],
        referenceDate: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 27)) ?? .now
    )
}

#Preview("Replay Empty") {
    ReplayView(
        workouts: [],
        referenceDate: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 27)) ?? .now
    )
}

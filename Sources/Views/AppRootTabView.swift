import SwiftUI

struct AppRootTabView: View {
    private enum AppTab: Hashable {
        case overview
        case workout
    }

    @Environment(WorkoutEndReminderCoordinator.self) private var reminderCoordinator
    @State private var draftStore = WorkoutDraftStore()
    @State private var selectedTab = AppTab.overview
    /// UI ScreenshotでOverviewの対象月を固定するための基準日時。
    var referenceDate: Date? = nil
    var monthlyInsightGenerator: any MonthlyInsightGenerating = AppleIntelligenceMonthlyInsightGenerator()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("概要", systemImage: "square.grid.2x2.fill", value: .overview) {
                NavigationStack {
                    OverviewView(
                        referenceDate: referenceDate,
                        insightGenerator: monthlyInsightGenerator
                    )
                }
            }

            Tab(
                "ワークアウト",
                systemImage: "figure.strengthtraining.traditional",
                value: .workout
            ) {
                NavigationStack {
                    WorkoutRootView(draftStore: draftStore)
                }
            }
        }
        .task {
            routePendingNotificationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutEndReminderTapped)) { _ in
            routePendingNotificationIfNeeded()
        }
    }

    private func routePendingNotificationIfNeeded() {
        guard reminderCoordinator.consumeNotificationTap() != nil else { return }
        selectedTab = .workout
    }
}

#Preview {
    AppRootTabView()
        .modelContainer(
            for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
            inMemory: true
        )
        .environment(
            WorkoutEndReminderCoordinator(
                notificationCenter: DisabledWorkoutEndReminderNotificationCenter()
            )
        )
}

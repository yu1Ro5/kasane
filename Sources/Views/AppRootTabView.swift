import SwiftData
import SwiftUI

struct AppRootTabView: View {
    private enum AppTab: Hashable {
        case overview
        case workout
    }

    @Environment(WorkoutEndReminderCoordinator.self) private var reminderCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
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
            await checkForReminder()
            reminderCoordinator.requestCheck()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            routePendingNotificationIfNeeded()
            Task {
                await checkForReminder()
                reminderCoordinator.requestCheck()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutEndReminderTapped)) { _ in
            routePendingNotificationIfNeeded()
            Task {
                await checkForReminder()
                reminderCoordinator.requestCheck()
            }
        }
    }

    private func routePendingNotificationIfNeeded() {
        guard reminderCoordinator.consumeNotificationTap() else { return }
        selectedTab = .workout
    }

    private func checkForReminder() async {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\WorkoutSession.startedAt)]
        )
        guard let activeSessions = try? modelContext.fetch(descriptor) else { return }
        await reminderCoordinator.reconcile(activeSessions: activeSessions)
        if let presentedWorkoutID = reminderCoordinator.presentedWorkoutID,
            !activeSessions.contains(where: { $0.id == presentedWorkoutID })
        {
            reminderCoordinator.dismissReminder(for: presentedWorkoutID)
        }

        if reminderCoordinator.tappedWorkoutID != nil {
            selectedTab = .workout
            return
        }
        guard
            let overdueSession = activeSessions.first(where: {
                reminderCoordinator.shouldPresentReminder(for: $0)
            })
        else { return }
        selectedTab = .workout
        reminderCoordinator.presentReminder(for: overdueSession.id)
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

import SwiftData
import SwiftUI

struct WorkoutRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt == nil },
        sort: \WorkoutSession.startedAt
    ) private var activeSessions: [WorkoutSession]

    @State private var viewModel = WorkoutRootViewModel()

    private var activeSession: WorkoutSession? {
        activeSessions.first
    }

    private var displayedActiveSession: WorkoutSession? {
        viewModel.isStartingNewWorkout ? nil : activeSession
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(
                systemName: displayedActiveSession == nil
                    ? "figure.strengthtraining.traditional" : "clock.arrow.circlepath"
            )
            .font(.system(size: 52))
            .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text(displayedActiveSession == nil ? "ワークアウトを始めましょう" : "進行中のワークアウト")
                    .font(.title2.bold())

                if let displayedActiveSession {
                    Text(displayedActiveSession.startedAt, format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(.secondary)
                }
            }

            Button(displayedActiveSession == nil ? "ワークアウトを開始" : "ワークアウトを再開") {
                openWorkout()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("workout-resume-button")

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .navigationTitle("KASANE")
        .navigationDestination(item: selectedSession) { session in
            WorkoutSessionView(session: session) { viewModel.closeWorkout() }
        }
        .alert("ワークアウトを開けませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラーが発生しました。")
        }
        .task {
            seedExercises()
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var selectedSession: Binding<WorkoutSession?> {
        Binding(
            get: { viewModel.selectedSession },
            set: { if $0 == nil { viewModel.closeWorkout() } }
        )
    }

    private func openWorkout() {
        viewModel.openWorkout(activeSession: activeSession) {
            try WorkoutSessionService(context: modelContext).startOrResume()
        }
    }

    private func seedExercises() {
        do {
            try ExerciseCatalogService(context: modelContext).seed()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutRootView()
    }
    .modelContainer(
        for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
        inMemory: true
    )
}

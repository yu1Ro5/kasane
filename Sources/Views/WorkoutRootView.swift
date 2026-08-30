import SwiftData
import SwiftUI

struct WorkoutRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WorkoutRootViewModel()
    let draftStore: WorkoutDraftStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(
                systemName: viewModel.activeSession == nil
                    ? "figure.strengthtraining.traditional" : "clock.arrow.circlepath"
            )
            .font(.system(size: 52))
            .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text(viewModel.activeSession == nil ? "ワークアウトを始めましょう" : "進行中のワークアウト")
                    .font(.title2.bold())

                if let activeSession = viewModel.activeSession {
                    Text(activeSession.startedAt, format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(.secondary)
                }
            }

            Button(viewModel.activeSession == nil ? "ワークアウトを開始" : "ワークアウトを再開") {
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
            WorkoutSessionView(session: session, draftStore: draftStore) { closeWorkout() }
        }
        .alert("ワークアウトを開けませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラーが発生しました。")
        }
        .task {
            seedExercises()
            refreshActiveSession()
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
            set: { if $0 == nil { closeWorkout() } }
        )
    }

    private func openWorkout() {
        viewModel.openWorkout {
            try WorkoutSessionService(context: modelContext).startOrResume()
        }
    }

    private func closeWorkout() {
        viewModel.closeWorkout()
        refreshActiveSession()
    }

    private func refreshActiveSession() {
        viewModel.refreshActiveSession {
            try WorkoutSessionService(context: modelContext).activeSession()
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
        WorkoutRootView(draftStore: WorkoutDraftStore())
    }
    .modelContainer(
        for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
        inMemory: true
    )
}

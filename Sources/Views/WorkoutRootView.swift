import SwiftData
import SwiftUI

struct WorkoutRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WorkoutRootViewModel()
    let draftStore: WorkoutDraftStore

    var body: some View {
        Group {
            if let activeSession = viewModel.activeSession {
                WorkoutSessionView(
                    session: activeSession,
                    draftStore: draftStore,
                    onReturnHome: refreshActiveSession
                )
            } else {
                startContent
            }
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

    private var startContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("ワークアウトを始めましょう")
                .font(.title2.bold())

            Button("ワークアウトを開始") {
                startWorkout()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("workout-start-button")

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .navigationTitle("ワークアウト")
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func startWorkout() {
        viewModel.startWorkout {
            try WorkoutSessionService(context: modelContext).startOrResume()
        }
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

import SwiftData
import SwiftUI

struct WorkoutRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WorkoutRootViewModel()
    @Query(WorkoutSessionService.recentCompletedDescriptor) private var recentSessions: [WorkoutSession]
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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("今日も、積み重ねよう。")
                    .font(.title2.bold())

                Button("ワークアウトを開始") {
                    startWorkout()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("workout-start-button")

                if !recentSessions.isEmpty {
                    Text("最近のワークアウトから開始")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(recentSessions) { session in
                        recentWorkoutCard(session)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ワークアウト")
    }

    private func recentWorkoutCard(_ session: WorkoutSession) -> some View {
        let entries = session.exerciseEntries.sorted { $0.order < $1.order }
        let canReuse = !WorkoutSessionService.reusableExercises(from: session).isEmpty
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Text("\(entries.count)種目")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(entries.prefix(3).map(\.exerciseNameSnapshot).joined(separator: "、"))
                    .font(.subheadline)
                if entries.count > 3 {
                    Text("ほか\(entries.count - 3)種目")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            Button("この種目で開始") {
                startWorkout(reusing: session)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!canReuse)
            .accessibilityIdentifier("workout-reuse-\(session.id.uuidString)")

            if !canReuse {
                Text("引き継げる種目がありません")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func startWorkout(reusing session: WorkoutSession? = nil) {
        viewModel.startWorkout {
            try WorkoutSessionService(context: modelContext).startOrResume(reusing: session)
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

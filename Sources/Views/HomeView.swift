import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt == nil },
        sort: \WorkoutSession.startedAt
    ) private var activeSessions: [WorkoutSession]

    @State private var selectedSession: WorkoutSession?
    @State private var errorMessage: String?

    private var activeSession: WorkoutSession? {
        activeSessions.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(
                    systemName: activeSession == nil ? "figure.strengthtraining.traditional" : "clock.arrow.circlepath"
                )
                .font(.system(size: 52))
                .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text(activeSession == nil ? "ワークアウトを始めましょう" : "進行中のワークアウト")
                        .font(.title2.bold())

                    if let activeSession {
                        Text(activeSession.startedAt, format: .dateTime.year().month().day().hour().minute())
                            .foregroundStyle(.secondary)
                    }
                }

                Button(activeSession == nil ? "ワークアウトを開始" : "ワークアウトを再開") {
                    openWorkout()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .navigationTitle("KASANE")
            .navigationDestination(item: $selectedSession) { session in
                WorkoutSessionView(session: session)
            }
            .alert("ワークアウトを開けませんでした", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました。")
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func openWorkout() {
        do {
            selectedSession = try WorkoutSessionService(context: modelContext).startOrResume()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(
            for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
            inMemory: true
        )
}

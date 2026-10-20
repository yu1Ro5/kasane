import SwiftData
import SwiftUI

struct WorkoutRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    @ViewBuilder
    private var startContent: some View {
        if recentSessions.isEmpty {
            emptyStartContent
        } else {
            smartStartContent
        }
    }

    // 履歴がない場合は、従来どおり主要操作を画面中央へ配置する。
    private var emptyStartContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("今日も、積み重ねよう。")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Button("ワークアウトを開始") {
                    startWorkout()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("workout-start-button")
            }
            .frame(maxWidth: .infinity)
            .padding(18)
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ワークアウト")
    }

    // 履歴がある場合は通常開始を目立たせ、その下にコンパクトな3件を並べる。
    private var smartStartContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("今日も、積み重ねよう。")
                    .font(.title2.bold())

                Button {
                    startWorkout()
                } label: {
                    Text("ワークアウトを開始")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("workout-start-button")

                VStack(alignment: .leading, spacing: 10) {
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

    // カード全体を1つのボタンにし、通常サイズでは「日付+開始」「種目名」の2行にする。
    private func recentWorkoutCard(_ session: WorkoutSession) -> some View {
        let entries = session.exerciseEntries.sorted { $0.order < $1.order }
        let canReuse = !WorkoutSessionService.reusableExercises(from: session).isEmpty
        let dateText = displayDate(session.startedAt)
        let summary = exerciseSummary(entries)
        let fullNames = entries.map(\.exerciseNameSnapshot).joined(separator: "、")
        let accessibleNames = fullNames.isEmpty ? "種目の記録なし" : fullNames
        let accessibleDate = session.startedAt.formatted(date: .complete, time: .omitted)
        let accessibilityText = canReuse
            ? "\(accessibleDate)、\(entries.count)種目、\(accessibleNames)でワークアウトを開始"
            : "\(accessibleDate)、\(entries.count)種目、\(accessibleNames)。引き継げる種目がありません"

        return Button {
            startWorkout(reusing: session)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                let headerLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout(spacing: 8))
                headerLayout {
                    Text(dateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(entries.count)種目")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 8)
                    }

                    if canReuse {
                        HStack(spacing: 4) {
                            Text("開始")
                            Image(systemName: "chevron.forward")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    } else {
                        Text("利用不可")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !canReuse {
                    Text("引き継げる種目がありません")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!canReuse)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityHint(
            Text(
                canReuse
                    ? "過去の種目だけを引き継ぎ、重量や回数はコピーしません"
                    : "通常の開始ボタンから始めてください"
            )
        )
        .accessibilityIdentifier("workout-reuse-\(session.id.uuidString)")
    }

    private func displayDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.component(.year, from: date) == calendar.component(.year, from: .now) {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.year().month().day())
    }

    private func exerciseSummary(_ entries: [ExerciseEntry]) -> String {
        guard !entries.isEmpty else { return "種目の記録がありません" }
        let names = entries.prefix(2).map(\.exerciseNameSnapshot).joined(separator: "、")
        let remaining = entries.count - 2
        return remaining > 0 ? "\(names)、ほか\(remaining)種目" : names
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

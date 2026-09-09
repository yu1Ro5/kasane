import SwiftData
import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @Bindable var draftStore: WorkoutDraftStore
    let onReturnHome: () -> Void

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]
    @Query(sort: \SetEntry.order) private var observedSetEntries: [SetEntry]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var observedSessions: [WorkoutSession]

    @State private var selectedExerciseID: UUID?
    @State private var searchText = ""
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingEmptyDiscard = false
    @State private var isFinishing = false
    @State private var completionSummary: WorkoutCompletionSummary?
    @State private var errorTitle = ""
    @State private var errorMessage: String?

    private var content: WorkoutSessionContent {
        WorkoutSessionContent(
            exerciseEntries: observedExerciseEntries.filter { $0.workoutSession?.id == session.id }
        )
    }

    private var sortedEntries: [ExerciseEntry] {
        content.exerciseEntries
    }

    private var availableExercises: [Exercise] {
        content.availableExercises(from: exercises, matching: searchText)
    }

    var body: some View {
        List {
            if searchText.isEmpty {
                Section("今回のワークアウト") {
                    if sortedEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("まだ記録した種目はありません")
                            Text(
                                "開始: \(session.startedAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedEntries) { entry in
                            if let exercise = entry.exercise {
                                Button {
                                    selectedExerciseID = exercise.id
                                } label: {
                                    WorkoutExerciseListRow(
                                        name: entry.exerciseNameSnapshot,
                                        detail: currentSummary(for: entry)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    "current-exercise-\(exercise.id.uuidString)"
                                )
                            } else {
                                WorkoutExerciseListRow(
                                    name: entry.exerciseNameSnapshot,
                                    detail: currentSummary(for: entry),
                                    showsDisclosureIndicator: false
                                )
                            }
                        }
                    }
                }
            }

            Section("すべての種目") {
                if availableExercises.isEmpty {
                    if searchText.isEmpty {
                        Text("記録できる種目はありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    ForEach(availableExercises) { exercise in
                        Button {
                            selectedExerciseID = exercise.id
                        } label: {
                            WorkoutExerciseListRow(
                                name: exercise.name,
                                detail: previousSummary(for: exercise)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("available-exercise-\(exercise.id.uuidString)")
                    }
                }
            }
        }
        .navigationTitle("ワークアウト")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "種目名を検索"
        )
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("終了", systemImage: "checkmark") { requestFinish() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFinishing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("ワークアウトを中止", systemImage: "trash", role: .destructive) {
                        isConfirmingDiscard = true
                    }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
        .navigationDestination(item: $selectedExerciseID) { exerciseID in
            if let exercise = exercises.first(where: { $0.id == exerciseID }) {
                WorkoutExerciseInputView(
                    session: session,
                    exercise: exercise,
                    draftStore: draftStore
                )
            } else {
                ContentUnavailableView("種目を開けません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationDestination(item: $completionSummary) { summary in
            WorkoutCompletedView(summary: summary, onReturnHome: returnHomeAfterCompletion)
        }
        .confirmationDialog("ワークアウトを中止しますか？", isPresented: $isConfirmingDiscard) {
            Button("中止する", role: .destructive) { discardWorkout() }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("このワークアウトの記録は削除され、元に戻せません。")
        }
        .confirmationDialog("ワークアウトを終了しますか？", isPresented: $isConfirmingFinish) {
            Button("終了して保存") { finishWorkout() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("記録済み: \(completionCounts.exerciseCount)種目・\(completionCounts.setCount)セット")
        }
        .confirmationDialog("記録されたセットがありません", isPresented: $isConfirmingEmptyDiscard) {
            Button("中止する", role: .destructive) { discardWorkout() }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("完了済みとして保存せず、このワークアウトを中止します。")
        }
        .alert(errorTitle, isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var sessionDrafts: [UUID: SetEntryDraft] {
        draftStore.drafts(for: session.id)
    }

    private var pendingExerciseDrafts: [UUID: SetEntryDraft] {
        draftStore.pendingDrafts(for: session.id)
    }

    private var completionCounts: (exerciseCount: Int, setCount: Int) {
        let entries = sortedEntries.filter {
            !sortedSets(for: $0).isEmpty || sessionDrafts[$0.id]?.values() != nil
        }
        return (
            entries.count,
            entries.reduce(0) {
                $0 + sortedSets(for: $1).count + (sessionDrafts[$1.id]?.values() == nil ? 0 : 1)
            }
        )
    }

    private func sortedSets(for entry: ExerciseEntry) -> [SetEntry] {
        observedSetEntries.filter { $0.exerciseEntry?.id == entry.id }
    }

    private func currentSummary(for entry: ExerciseEntry) -> String {
        let sets = sortedSets(for: entry)
        return sets.isEmpty
            ? "入力中"
            : WorkoutSetDisplayFormatter.summary(prefix: "今回", setEntries: sets)
    }

    private func previousSummary(for exercise: Exercise) -> String {
        guard
            let record = PreviousWorkoutRecordContent.find(
                for: exercise,
                in: session,
                sessions: observedSessions
            )
        else { return "記録なし" }
        return WorkoutSetDisplayFormatter.summary(prefix: "前回", setEntries: record.setEntries)
    }

    private func requestFinish() {
        guard !isFinishing else { return }
        if !pendingExerciseDrafts.isEmpty {
            errorTitle = "未保存のセットがあります"
            errorMessage = "入力中の種目を開き、「セットを追加」を押すか入力を消してから終了してください。"
        } else if sessionDrafts.values.contains(where: { !$0.isEmpty && $0.values() == nil }) {
            errorTitle = "未追加のセットがあります"
            errorMessage = "重量と回数を正しく入力するか、入力を消してから終了してください。"
        } else if completionCounts.setCount == 0 {
            isConfirmingEmptyDiscard = true
        } else {
            isConfirmingFinish = true
        }
    }

    private func finishWorkout() {
        guard !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }
        do {
            completionSummary = try WorkoutSessionService(context: modelContext).finish(
                session,
                drafts: sessionDrafts
            )
            draftStore.removeAllDrafts(in: session.id)
        } catch {
            errorTitle = "ワークアウトを終了できませんでした"
            errorMessage = error.localizedDescription
        }
    }

    private func discardWorkout() {
        do {
            try WorkoutSessionService(context: modelContext).discard(session)
            draftStore.removeAllDrafts(in: session.id)
            onReturnHome()
        } catch {
            errorTitle = "ワークアウトを中止できませんでした"
            errorMessage = error.localizedDescription
        }
    }

    private func returnHomeAfterCompletion() {
        completionSummary = nil
        onReturnHome()
    }
}

private struct WorkoutExerciseListRow: View {
    let name: String
    let detail: String
    var showsDisclosureIndicator = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showsDisclosureIndicator {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

import SwiftData
import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    let onReturnHome: () -> Void

    @State private var isShowingPicker = false
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingEmptyDiscard = false
    @State private var isFinishing = false
    @State private var completionSummary: WorkoutCompletionSummary?
    @State private var drafts: [UUID: SetEntryDraft] = [:]
    @State private var entryPendingDeletion: ExerciseEntry?
    @State private var errorTitle = ""
    @State private var errorMessage: String?

    private var sortedEntries: [ExerciseEntry] {
        session.exerciseEntries.sorted { $0.order < $1.order }
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                ContentUnavailableView {
                    Label("種目がありません", systemImage: "dumbbell")
                } description: {
                    Text("開始: \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                } actions: {
                    Button("種目を追加") { isShowingPicker = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(sortedEntries) { entry in
                        WorkoutExerciseSection(
                            entry: entry,
                            draft: draftBinding(for: entry),
                            onDeleteExercise: { requestDeletion(of: entry) }
                        )
                    }
                }
            }
        }
        .navigationTitle("ワークアウト")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("終了") { requestFinish() }
                    .disabled(isFinishing)
                Button("種目を追加", systemImage: "plus") { isShowingPicker = true }
                Menu {
                    Button("ワークアウトを破棄", systemImage: "trash", role: .destructive) {
                        isConfirmingDiscard = true
                    }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
        .navigationDestination(item: $completionSummary) { summary in
            WorkoutCompletedView(summary: summary, onReturnHome: onReturnHome)
        }
        .sheet(isPresented: $isShowingPicker) {
            ExercisePickerView(
                selectedExerciseIDs: Set(session.exerciseEntries.compactMap { $0.exercise?.id }),
                onSelect: addExercise
            )
        }
        .confirmationDialog("このワークアウトを破棄しますか？", isPresented: $isConfirmingDiscard) {
            Button("ワークアウトを破棄", role: .destructive) { discardWorkout() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("入力した内容はすべて削除され、元に戻せません。")
        }
        .confirmationDialog("ワークアウトを終了しますか？", isPresented: $isConfirmingFinish) {
            Button("終了して保存") { finishWorkout() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("記録済み: \(completionCounts.exerciseCount)種目・\(completionCounts.setCount)セット")
        }
        .confirmationDialog("記録されたセットがありません", isPresented: $isConfirmingEmptyDiscard) {
            Button("ワークアウトを破棄", role: .destructive) { discardWorkout() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("完了済みとして保存せず、このワークアウトを破棄しますか？")
        }
        .confirmationDialog(
            "この種目を削除しますか？",
            isPresented: deletionConfirmationIsPresented,
            presenting: entryPendingDeletion
        ) { entry in
            Button("種目を削除", role: .destructive) { deleteExercise(entry) }
            Button("キャンセル", role: .cancel) { entryPendingDeletion = nil }
        } message: { entry in
            Text(entry.setEntries.isEmpty ? "この操作は元に戻せません。" : "保存済みのセットもすべて削除されます。")
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

    private var deletionConfirmationIsPresented: Binding<Bool> {
        Binding(get: { entryPendingDeletion != nil }, set: { if !$0 { entryPendingDeletion = nil } })
    }

    private var completionCounts: (exerciseCount: Int, setCount: Int) {
        let entries = session.exerciseEntries.filter { !$0.setEntries.isEmpty }
        return (entries.count, entries.reduce(0) { $0 + $1.setEntries.count })
    }

    private func draftBinding(for entry: ExerciseEntry) -> Binding<SetEntryDraft> {
        Binding(
            get: { drafts[entry.id] ?? SetEntryDraft() },
            set: { drafts[entry.id] = $0 }
        )
    }

    private func requestFinish() {
        guard !isFinishing else { return }
        if drafts.values.contains(where: { !$0.isEmpty }) {
            errorTitle = "未追加のセットがあります"
            errorMessage = "「セットを追加」するか、重量と回数の入力を消してから終了してください。"
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
            completionSummary = try WorkoutSessionService(context: modelContext).finish(session)
        } catch {
            errorTitle = "ワークアウトを終了できませんでした"
            errorMessage = error.localizedDescription
        }
    }

    private func addExercise(_ exercise: Exercise) throws {
        _ = try WorkoutExerciseService(context: modelContext).add(exercise, to: session)
    }

    private func requestDeletion(of entry: ExerciseEntry) {
        if entry.setEntries.isEmpty {
            deleteExercise(entry)
        } else {
            entryPendingDeletion = entry
        }
    }

    private func deleteExercise(_ entry: ExerciseEntry) {
        do {
            try WorkoutExerciseService(context: modelContext).delete(entry, from: session)
            drafts[entry.id] = nil
            entryPendingDeletion = nil
        } catch {
            errorTitle = "種目を削除できませんでした"
            errorMessage = error.localizedDescription
        }
    }

    private func discardWorkout() {
        do {
            try WorkoutSessionService(context: modelContext).discard(session)
            dismiss()
        } catch {
            errorTitle = "ワークアウトを破棄できませんでした"
            errorMessage = error.localizedDescription
        }
    }
}

private struct WorkoutExerciseSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: ExerciseEntry
    @Binding var draft: SetEntryDraft
    let onDeleteExercise: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: DraftField?

    private var sortedSets: [SetEntry] {
        entry.setEntries.sorted { $0.order < $1.order }
    }

    var body: some View {
        Section {
            ForEach(sortedSets) { setEntry in
                WorkoutSetRow(setEntry: setEntry, exerciseEntry: entry)
            }
            HStack {
                Text("Set \(sortedSets.count + 1)")
                TextField("重量 (kg)", text: $draft.weight)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .reps }
                TextField("回数", text: $draft.reps)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .reps)
            }
            Button("セットを追加", systemImage: "plus") { addSet() }
                .disabled(draft.values() == nil || isSaving)
        } header: {
            HStack {
                Text(entry.exerciseNameSnapshot)
                Spacer()
                Menu {
                    Button("種目を削除", systemImage: "trash", role: .destructive) {
                        onDeleteExercise()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                if focusedField == .weight {
                    Button("次へ") { focusedField = .reps }
                }
                Button("完了") { focusedField = nil }
            }
        }
        .alert("セットを保存できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func addSet() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try WorkoutSetService(context: modelContext).add(draft: draft, to: entry)
            draft = SetEntryDraft()
            focusedField = .weight
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private enum DraftField: Hashable {
        case weight
        case reps
    }
}

private struct WorkoutSetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var setEntry: SetEntry
    let exerciseEntry: ExerciseEntry

    @State private var editDraft: SetEntryDraft
    @State private var errorMessage: String?
    @FocusState private var focusedField: EditField?

    init(setEntry: SetEntry, exerciseEntry: ExerciseEntry) {
        self.setEntry = setEntry
        self.exerciseEntry = exerciseEntry
        _editDraft = State(initialValue: .savedValues(from: setEntry))
    }

    var body: some View {
        HStack {
            Text("Set \(setEntry.order + 1)")
            TextField("重量 (kg)", text: $editDraft.weight)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
            TextField("回数", text: $editDraft.reps)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps)
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil && newValue == nil { saveEdits() }
        }
        .swipeActions {
            Button("削除", systemImage: "trash", role: .destructive) { deleteSet() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focusedField = nil }
            }
        }
        .alert("セットを更新できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func saveEdits() {
        do {
            try WorkoutSetService(context: modelContext).update(setEntry, draft: editDraft)
            editDraft = .savedValues(from: setEntry)
        } catch {
            editDraft = .savedValues(from: setEntry)
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSet() {
        do {
            try WorkoutSetService(context: modelContext).delete(setEntry, from: exerciseEntry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private enum EditField: Hashable {
        case weight
        case reps
    }
}

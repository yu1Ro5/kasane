import SwiftData
import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @Query private var exerciseEntries: [ExerciseEntry]
    let onReturnHome: () -> Void

    @State private var isShowingPicker = false
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingEmptyDiscard = false
    @State private var isFinishing = false
    @State private var completionSummary: WorkoutCompletionSummary?
    @State private var drafts: [UUID: SetEntryDraft] = [:]
    @State private var editDrafts: [UUID: SetEntryDraft] = [:]
    @State private var entryPendingDeletion: ExerciseEntry?
    @State private var errorTitle = ""
    @State private var errorMessage: String?
    @FocusState private var focusedInput: WorkoutInputFocus?

    init(session: WorkoutSession, onReturnHome: @escaping () -> Void) {
        self.session = session
        self.onReturnHome = onReturnHome
        let sessionID = session.id
        _exerciseEntries = Query(
            filter: #Predicate<ExerciseEntry> { entry in
                entry.workoutSession?.id == sessionID
            },
            sort: \ExerciseEntry.order
        )
    }

    var body: some View {
        Group {
            if exerciseEntries.isEmpty {
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
                    ForEach(exerciseEntries) { entry in
                        WorkoutExerciseSection(
                            entry: entry,
                            draft: draftBinding(for: entry),
                            editDraft: editDraftBinding,
                            focusedInput: $focusedInput,
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                if focusedInput?.nextInput != nil {
                    Button("次へ") { focusedInput = focusedInput?.nextInput }
                }
                Button("完了") { focusedInput = nil }
            }
        }
        .navigationDestination(item: $completionSummary) { summary in
            WorkoutCompletedView(summary: summary, onReturnHome: onReturnHome)
        }
        .sheet(isPresented: $isShowingPicker) {
            ExercisePickerView(
                selectedExerciseIDs: Set(exerciseEntries.compactMap { $0.exercise?.id }),
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
        let entries = exerciseEntries.filter {
            !$0.setEntries.isEmpty || drafts[$0.id]?.values() != nil
        }
        return (
            entries.count,
            entries.reduce(0) { $0 + $1.setEntries.count + (drafts[$1.id]?.values() == nil ? 0 : 1) }
        )
    }

    private func draftBinding(for entry: ExerciseEntry) -> Binding<SetEntryDraft> {
        Binding(
            get: { drafts[entry.id] ?? SetEntryDraft() },
            set: { drafts[entry.id] = $0 }
        )
    }

    private func editDraftBinding(for setEntry: SetEntry) -> Binding<SetEntryDraft> {
        Binding(
            get: { editDrafts[setEntry.id] ?? .savedValues(from: setEntry) },
            set: { editDrafts[setEntry.id] = $0 }
        )
    }

    private var hasUnsavedSetEdits: Bool {
        exerciseEntries
            .flatMap(\.setEntries)
            .contains { setEntry in
                editDrafts[setEntry.id]?.hasChanges(from: setEntry) == true
            }
    }

    private func requestFinish() {
        guard !isFinishing else { return }
        if hasUnsavedSetEdits {
            errorTitle = "編集中のセットがあります"
            errorMessage = "キーボードの「完了」を押して編集を保存してから終了してください。"
        } else if drafts.values.contains(where: { !$0.isEmpty && $0.values() == nil }) {
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
                drafts: drafts
            )
            drafts.removeAll()
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
            entry.setEntries.forEach { editDrafts[$0.id] = nil }
            if focusedInput?.exerciseID == entry.id { focusedInput = nil }
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
    @Query private var setEntries: [SetEntry]
    @Binding var draft: SetEntryDraft
    let editDraft: (SetEntry) -> Binding<SetEntryDraft>
    var focusedInput: FocusState<WorkoutInputFocus?>.Binding
    let onDeleteExercise: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        entry: ExerciseEntry,
        draft: Binding<SetEntryDraft>,
        editDraft: @escaping (SetEntry) -> Binding<SetEntryDraft>,
        onDeleteExercise: @escaping () -> Void
    ) {
        self.entry = entry
        _draft = draft
        self.editDraft = editDraft
        self.onDeleteExercise = onDeleteExercise
        let entryID = entry.id
        _setEntries = Query(
            filter: #Predicate<SetEntry> { setEntry in
                setEntry.exerciseEntry?.id == entryID
            },
            sort: \SetEntry.order
        )
    }

    var body: some View {
        Section {
            ForEach(setEntries) { setEntry in
                WorkoutSetRow(
                    setEntry: setEntry,
                    exerciseEntry: entry,
                    editDraft: editDraft(setEntry),
                    focusedInput: focusedInput
                )
            }
            HStack {
                Text("Set \(setEntries.count + 1)")
                TextField("重量 (kg)", text: $draft.weight)
                    .accessibilityIdentifier("draft-weight-input")
                    .keyboardType(.decimalPad)
                    .focused(focusedInput, equals: .draftWeight(exerciseID: entry.id))
                    .submitLabel(.next)
                    .onSubmit { focusedInput.wrappedValue = .draftReps(exerciseID: entry.id) }
                TextField("回数", text: $draft.reps)
                    .accessibilityIdentifier("draft-reps-input")
                    .keyboardType(.numberPad)
                    .focused(focusedInput, equals: .draftReps(exerciseID: entry.id))
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
            focusedInput.wrappedValue = .draftWeight(exerciseID: entry.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WorkoutSetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var setEntry: SetEntry
    let exerciseEntry: ExerciseEntry

    @Binding var editDraft: SetEntryDraft
    var focusedInput: FocusState<WorkoutInputFocus?>.Binding
    @State private var errorMessage: String?

    var body: some View {
        HStack {
            Text("Set \(setEntry.order + 1)")
            TextField("重量 (kg)", text: $editDraft.weight)
                .keyboardType(.decimalPad)
                .focused(
                    focusedInput,
                    equals: .savedWeight(exerciseID: exerciseEntry.id, setID: setEntry.id)
                )
            TextField("回数", text: $editDraft.reps)
                .keyboardType(.numberPad)
                .focused(
                    focusedInput,
                    equals: .savedReps(exerciseID: exerciseEntry.id, setID: setEntry.id)
                )
        }
        .onChange(of: focusedInput.wrappedValue) { oldValue, newValue in
            let rowIdentity = WorkoutInputFocus.SavedSetIdentity(
                exerciseID: exerciseEntry.id,
                setID: setEntry.id
            )
            if oldValue?.savedSetIdentity == rowIdentity && newValue?.savedSetIdentity != rowIdentity {
                saveEdits()
            }
        }
        .swipeActions {
            Button("削除", systemImage: "trash", role: .destructive) { deleteSet() }
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
}

enum WorkoutInputFocus: Hashable {
    struct SavedSetIdentity: Hashable {
        let exerciseID: UUID
        let setID: UUID
    }

    case draftWeight(exerciseID: UUID)
    case draftReps(exerciseID: UUID)
    case savedWeight(exerciseID: UUID, setID: UUID)
    case savedReps(exerciseID: UUID, setID: UUID)

    var exerciseID: UUID {
        switch self {
        case .draftWeight(let exerciseID), .draftReps(let exerciseID),
            .savedWeight(let exerciseID, _), .savedReps(let exerciseID, _):
            exerciseID
        }
    }

    var savedSetIdentity: SavedSetIdentity? {
        switch self {
        case .draftWeight, .draftReps:
            nil
        case .savedWeight(let exerciseID, let setID), .savedReps(let exerciseID, let setID):
            SavedSetIdentity(exerciseID: exerciseID, setID: setID)
        }
    }

    var nextInput: WorkoutInputFocus? {
        guard case .draftWeight(let exerciseID) = self else { return nil }
        return .draftReps(exerciseID: exerciseID)
    }
}

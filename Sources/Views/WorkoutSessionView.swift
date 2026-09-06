import SwiftData
import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]
    @Query(sort: \SetEntry.order) private var observedSetEntries: [SetEntry]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var observedSessions: [WorkoutSession]
    @Bindable var draftStore: WorkoutDraftStore
    let onReturnHome: () -> Void

    @State private var isShowingPicker = false
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingEmptyDiscard = false
    @State private var isFinishing = false
    @State private var completionSummary: WorkoutCompletionSummary?
    @State private var editDrafts: [UUID: SetEntryDraft] = [:]
    @State private var entryPendingDeletion: ExerciseEntry?
    @State private var errorTitle = ""
    @State private var errorMessage: String?
    @FocusState private var focusedInput: WorkoutInputFocus?

    private var sortedEntries: [ExerciseEntry] {
        WorkoutSessionContent(
            exerciseEntries: observedExerciseEntries.filter { $0.workoutSession?.id == session.id }
        ).exerciseEntries
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
                            setEntries: sortedSets(for: entry),
                            previousRecord: PreviousWorkoutRecordContent.find(
                                for: entry,
                                in: session,
                                sessions: observedSessions
                            ),
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
            ToolbarItem(placement: .confirmationAction) {
                Button("終了", systemImage: "checkmark") { requestFinish() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFinishing)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("種目を追加", systemImage: "plus") { isShowingPicker = true }
                Menu {
                    Button("ワークアウトを中止", systemImage: "trash", role: .destructive) {
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
                } else {
                    Button("完了") { focusedInput = nil }
                }
            }
        }
        .navigationDestination(item: $completionSummary) { summary in
            WorkoutCompletedView(summary: summary, onReturnHome: onReturnHome)
        }
        .sheet(isPresented: $isShowingPicker) {
            ExercisePickerView(
                selectedExerciseIDs: Set(sortedEntries.compactMap { $0.exercise?.id }),
                onSelect: addExercise
            )
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
        .confirmationDialog(
            "この種目を削除しますか？",
            isPresented: deletionConfirmationIsPresented,
            presenting: entryPendingDeletion
        ) { entry in
            Button("種目を削除", role: .destructive) { deleteExercise(entry) }
            Button("キャンセル", role: .cancel) { entryPendingDeletion = nil }
        } message: { entry in
            Text(
                sortedSets(for: entry).isEmpty
                    ? "この操作は元に戻せません。" : "保存済みのセットもすべて削除されます。"
            )
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

    private var sessionDrafts: [UUID: SetEntryDraft] {
        draftStore.drafts(for: session.id)
    }

    private func draftBinding(for entry: ExerciseEntry) -> Binding<SetEntryDraft> {
        Binding(
            get: { draftStore.draft(for: entry.id, in: session.id) },
            set: { draftStore.update($0, for: entry.id, in: session.id) }
        )
    }

    private func editDraftBinding(for setEntry: SetEntry) -> Binding<SetEntryDraft> {
        Binding(
            get: { editDrafts[setEntry.id] ?? .savedValues(from: setEntry) },
            set: { editDrafts[setEntry.id] = $0 }
        )
    }

    private var hasUnsavedSetEdits: Bool {
        sortedEntries
            .flatMap { sortedSets(for: $0) }
            .contains { setEntry in
                editDrafts[setEntry.id]?.hasChanges(from: setEntry) == true
            }
    }

    private func requestFinish() {
        guard !isFinishing else { return }
        if hasUnsavedSetEdits {
            errorTitle = "編集中のセットがあります"
            errorMessage = "キーボードの「完了」を押して編集を保存してから終了してください。"
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

    private func addExercise(_ exercise: Exercise) throws {
        _ = try WorkoutExerciseService(context: modelContext).add(exercise, to: session)
    }

    private func requestDeletion(of entry: ExerciseEntry) {
        if sortedSets(for: entry).isEmpty {
            deleteExercise(entry)
        } else {
            entryPendingDeletion = entry
        }
    }

    private func deleteExercise(_ entry: ExerciseEntry) {
        do {
            let deletedSetIDs = sortedSets(for: entry).map(\.id)
            try WorkoutExerciseService(context: modelContext).delete(entry, from: session)
            draftStore.removeDraft(for: entry.id, in: session.id)
            deletedSetIDs.forEach { editDrafts[$0] = nil }
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
            draftStore.removeAllDrafts(in: session.id)
            dismiss()
        } catch {
            errorTitle = "ワークアウトを中止できませんでした"
            errorMessage = error.localizedDescription
        }
    }
}

private struct WorkoutExerciseSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: ExerciseEntry
    let setEntries: [SetEntry]
    let previousRecord: PreviousWorkoutRecordContent?
    @Binding var draft: SetEntryDraft
    let editDraft: (SetEntry) -> Binding<SetEntryDraft>
    var focusedInput: FocusState<WorkoutInputFocus?>.Binding
    let onDeleteExercise: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if let previousRecord {
                PreviousWorkoutRecordView(entryID: entry.id, record: previousRecord)
            }
            WorkoutSetColumnHeader()
            ForEach(setEntries) { setEntry in
                WorkoutSetRow(
                    setEntry: setEntry,
                    exerciseEntry: entry,
                    editDraft: editDraft(setEntry),
                    focusedInput: focusedInput
                )
            }
            WorkoutSetColumns {
                Text(WorkoutSetDisplayFormatter.setNumber((setEntries.map(\.order).max() ?? -1) + 2))
                    .accessibilityLabel("セット \((setEntries.map(\.order).max() ?? -1) + 2)")
            } weight: {
                HStack(spacing: 4) {
                    TextField("重量", text: $draft.weight, prompt: Text("0"))
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .accessibilityIdentifier("draft-weight-input-\(entry.id.uuidString)")
                        .accessibilityLabel("\(entry.exerciseNameSnapshot)、次のセットの重量、kg")
                        .keyboardType(.decimalPad)
                        .focused(focusedInput, equals: .draftWeight(exerciseID: entry.id))
                        .submitLabel(.next)
                        .onSubmit { focusedInput.wrappedValue = .draftReps(exerciseID: entry.id) }
                    Text("kg")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            } reps: {
                TextField("回数", text: $draft.reps, prompt: Text("0"))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .accessibilityIdentifier("draft-reps-input-\(entry.id.uuidString)")
                    .accessibilityLabel("\(entry.exerciseNameSnapshot)、次のセットの回数")
                    .keyboardType(.numberPad)
                    .focused(focusedInput, equals: .draftReps(exerciseID: entry.id))
            }
            .textFieldStyle(.roundedBorder)

            if showsDraftValidation {
                Label(
                    "重量は0以上（小数点以下2桁まで）、回数は1以上で入力してください。",
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("draft-validation-message")
            }

            Button("セットを追加", systemImage: "plus") { addSet() }
                .accessibilityIdentifier("add-set-button-\(entry.id.uuidString)")
                .disabled(draft.values() == nil || isSaving)
                .accessibilityHint("入力した重量と回数を保存します")
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
                .accessibilityLabel("\(entry.exerciseNameSnapshot)の操作")
            }
            .font(.headline)
            .textCase(nil)
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

    private var showsDraftValidation: Bool {
        !draft.isEmpty && draft.values() == nil
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

private struct PreviousWorkoutRecordView: View {
    let entryID: UUID
    let record: PreviousWorkoutRecordContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .accessibilityHidden(true)
                Text("前回")
                Text(record.startedAt, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
            }
            .font(.subheadline.weight(.semibold))

            WorkoutSetColumnHeader()
            ForEach(record.setEntries) { setEntry in
                WorkoutSetColumns {
                    Text(WorkoutSetDisplayFormatter.setNumber(setEntry.order + 1))
                } weight: {
                    WorkoutWeightText(weightKg: setEntry.weightKg)
                } reps: {
                    Text(WorkoutSetDisplayFormatter.reps(setEntry.reps))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(record.exerciseNameSnapshot)、前回、セット \(setEntry.order + 1)、重量 \(WorkoutSetDisplayFormatter.displayWeight(setEntry.weightKg))、回数 \(setEntry.reps)"
                )
                .accessibilityIdentifier(
                    "previous-set-row-\(entryID.uuidString)-\(setEntry.order)"
                )
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("previous-workout-record-\(entryID.uuidString)")
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
        WorkoutSetColumns {
            Text(WorkoutSetDisplayFormatter.setNumber(setEntry.order + 1))
                .accessibilityLabel("セット \(setEntry.order + 1)")
        } weight: {
            if focusedInput.wrappedValue == savedWeightFocus {
                HStack(spacing: 4) {
                    TextField("重量", text: $editDraft.weight, prompt: Text("0"))
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("セット \(setEntry.order + 1)の重量、kg")
                        .focused(focusedInput, equals: savedWeightFocus)
                    Text("kg")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            } else {
                WorkoutWeightText(weightKg: displayedWeight)
                    .contentShape(Rectangle())
                    .onTapGesture { focusedInput.wrappedValue = savedWeightFocus }
                    .accessibilityLabel(
                        "重量、\(WorkoutSetDisplayFormatter.displayWeight(displayedWeight))"
                    )
                    .accessibilityHint("ダブルタップして編集")
                    .accessibilityAddTraits(.isButton)
            }
        } reps: {
            if focusedInput.wrappedValue == savedRepsFocus {
                TextField("回数", text: $editDraft.reps, prompt: Text("0"))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .keyboardType(.numberPad)
                    .accessibilityLabel("セット \(setEntry.order + 1)の回数")
                    .focused(focusedInput, equals: savedRepsFocus)
            } else {
                Text(displayedReps, format: .number)
                    .monospacedDigit()
                    .contentShape(Rectangle())
                    .onTapGesture { focusedInput.wrappedValue = savedRepsFocus }
                    .accessibilityLabel("回数、\(displayedReps)")
                    .accessibilityHint("ダブルタップして編集")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .textFieldStyle(.roundedBorder)
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

    private var savedWeightFocus: WorkoutInputFocus {
        .savedWeight(exerciseID: exerciseEntry.id, setID: setEntry.id)
    }

    private var savedRepsFocus: WorkoutInputFocus {
        .savedReps(exerciseID: exerciseEntry.id, setID: setEntry.id)
    }

    private var displayedWeight: Double {
        editDraft.values()?.weight ?? setEntry.weightKg
    }

    private var displayedReps: Int {
        editDraft.values()?.reps ?? setEntry.reps
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
        switch self {
        case .draftWeight(let exerciseID):
            .draftReps(exerciseID: exerciseID)
        case .savedWeight(let exerciseID, let setID):
            .savedReps(exerciseID: exerciseID, setID: setID)
        case .draftReps, .savedReps:
            nil
        }
    }
}

import SwiftData
import SwiftUI

/// 1種目の前回記録を参照しながら、今回のセットを入力する画面。
struct WorkoutExerciseInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @Bindable var exercise: Exercise
    @Bindable var draftStore: WorkoutDraftStore

    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]
    @Query(sort: \SetEntry.order) private var observedSetEntries: [SetEntry]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var observedSessions: [WorkoutSession]

    @State private var editDrafts: [UUID: SetEntryDraft] = [:]
    @State private var isSaving = false
    @State private var isConfirmingDeletion = false
    @State private var errorTitle = ""
    @State private var errorMessage: String?
    @FocusState private var focusedInput: WorkoutInputFocus?

    private var entry: ExerciseEntry? {
        observedExerciseEntries.first {
            $0.workoutSession?.id == session.id && $0.exercise?.id == exercise.id
        }
    }

    private var setEntries: [SetEntry] {
        guard let entry else { return [] }
        return observedSetEntries.filter { $0.exerciseEntry?.id == entry.id }
    }

    private var previousRecord: PreviousWorkoutRecordContent? {
        PreviousWorkoutRecordContent.find(
            for: exercise,
            in: session,
            sessions: observedSessions
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section("今回の記録") {
                    WorkoutSetColumnHeader()
                    if let entry {
                        ForEach(setEntries) { setEntry in
                            WorkoutSetRow(
                                setEntry: setEntry,
                                exerciseEntry: entry,
                                editDraft: editDraftBinding(for: setEntry),
                                focusedInput: $focusedInput,
                                onDelete: { deleteSet(setEntry, from: entry) }
                            )
                        }
                    }
                    draftRow
                        .id(draftScrollTarget)

                    if showsDraftValidation {
                        Label(
                            "重量は0以上（小数点以下2桁まで）、回数は1以上で入力してください。",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("draft-validation-message")
                    }

                    Button("セットを追加", systemImage: "plus") { addSet(using: proxy) }
                        .accessibilityIdentifier("add-set-button-\(inputIdentity.uuidString)")
                        .disabled(!canAddSet)
                        .accessibilityHint("入力した重量と回数を保存します")
                }

                Section("前回の記録") {
                    if let previousRecord {
                        PreviousWorkoutRecordView(exerciseID: exercise.id, record: previousRecord)
                    } else {
                        Text("記録なし")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if entry != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("種目を削除", systemImage: "trash", role: .destructive) {
                                requestDeletion()
                            }
                        } label: {
                            Label("その他", systemImage: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedInput != nil {
                        Button("次へ") { advanceFocus(using: proxy) }
                        Spacer()
                    }
                }
            }
            .confirmationDialog("この種目を削除しますか？", isPresented: $isConfirmingDeletion) {
                Button("種目を削除", role: .destructive) { deleteExercise() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("保存済みのセットもすべて削除されます。")
            }
            .alert(errorTitle, isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました。")
            }
            .onChange(of: focusedInput) { oldValue, newValue in
                saveSetWhenLeaving(oldValue, for: newValue)
            }
            .onDisappear { focusedInput = nil }
        }
    }

    private var inputIdentity: UUID {
        entry?.id ?? exercise.id
    }

    private var draft: Binding<SetEntryDraft> {
        if let entry {
            return Binding(
                get: { draftStore.draft(for: entry.id, in: session.id) },
                set: { draftStore.update($0, for: entry.id, in: session.id) }
            )
        }
        return Binding(
            get: { draftStore.pendingDraft(for: exercise.id, in: session.id) },
            set: { draftStore.updatePending($0, for: exercise.id, in: session.id) }
        )
    }

    private var draftRow: some View {
        WorkoutSetColumns {
            Text(WorkoutSetDisplayFormatter.setNumber((setEntries.map(\.order).max() ?? -1) + 2))
                .accessibilityLabel("セット \((setEntries.map(\.order).max() ?? -1) + 2)")
        } weight: {
            HStack(spacing: 4) {
                TextField("重量", text: draft.weight, prompt: Text("0"))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .accessibilityIdentifier("draft-weight-input-\(inputIdentity.uuidString)")
                    .accessibilityLabel("\(exercise.name)、次のセットの重量、kg")
                    .keyboardType(.decimalPad)
                    .focused($focusedInput, equals: .draftWeight(exerciseID: inputIdentity))
                    .submitLabel(.next)
                    .onSubmit { focusedInput = .draftReps(exerciseID: inputIdentity) }
                Text("kg")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        } reps: {
            TextField("回数", text: draft.reps, prompt: Text("0"))
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .accessibilityIdentifier("draft-reps-input-\(inputIdentity.uuidString)")
                .accessibilityLabel("\(exercise.name)、次のセットの回数")
                .keyboardType(.numberPad)
                .focused($focusedInput, equals: .draftReps(exerciseID: inputIdentity))
        }
        .textFieldStyle(.roundedBorder)
    }

    private var showsDraftValidation: Bool {
        !draft.wrappedValue.isEmpty && draft.wrappedValue.values() == nil
    }

    private var canAddSet: Bool {
        draft.wrappedValue.values() != nil && !isSaving
    }

    private var draftScrollTarget: String {
        "draft-set-\(exercise.id.uuidString)"
    }

    private func editDraftBinding(for setEntry: SetEntry) -> Binding<SetEntryDraft> {
        Binding(
            get: { editDrafts[setEntry.id] ?? .savedValues(from: setEntry) },
            set: { editDrafts[setEntry.id] = $0 }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func addSet(using proxy: ScrollViewProxy) {
        guard canAddSet else { return }
        isSaving = true
        do {
            let focusedEntry: ExerciseEntry
            if let entry {
                _ = try WorkoutSetService(context: modelContext).add(
                    draft: draft.wrappedValue,
                    to: entry
                )
                draft.wrappedValue = SetEntryDraft()
                focusedEntry = entry
            } else {
                focusedEntry = try WorkoutExerciseService(context: modelContext).recordFirstSet(
                    draft: draft.wrappedValue,
                    for: exercise,
                    in: session
                )
                draftStore.removePendingDraft(for: exercise.id, in: session.id)
            }
            Task { @MainActor in
                await Task.yield()
                focusedInput = .draftWeight(exerciseID: focusedEntry.id)
                withAnimation {
                    proxy.scrollTo(draftScrollTarget, anchor: .center)
                }
                isSaving = false
            }
        } catch {
            isSaving = false
            errorTitle = "セットを保存できませんでした"
            errorMessage = error.localizedDescription
        }
    }

    private func advanceFocus(using proxy: ScrollViewProxy) {
        guard let currentFocus = focusedInput else { return }
        if currentFocus.isDraftReps(exerciseID: inputIdentity) {
            addSet(using: proxy)
            return
        }

        guard
            let nextFocus = currentFocus.nextInput(
                savedSetIDs: setEntries.map(\.id),
                draftExerciseID: inputIdentity
            )
        else { return }
        if let identity = currentFocus.savedSetToCommit(whenMovingTo: nextFocus) {
            guard saveSetIfNeeded(for: identity) else { return }
        }
        focusedInput = nextFocus
    }

    private func saveSetWhenLeaving(
        _ oldFocus: WorkoutInputFocus?,
        for newFocus: WorkoutInputFocus?
    ) {
        guard let identity = oldFocus?.savedSetToCommit(whenMovingTo: newFocus) else { return }
        if !saveSetIfNeeded(for: identity) {
            focusedInput = oldFocus
        }
    }

    @discardableResult
    private func saveSetIfNeeded(
        for identity: WorkoutInputFocus.SavedSetIdentity?
    ) -> Bool {
        guard
            let identity,
            let setEntry = setEntries.first(where: { $0.id == identity.setID }),
            let editDraft = editDrafts[setEntry.id],
            editDraft.hasChanges(from: setEntry)
        else { return true }

        do {
            try WorkoutSetService(context: modelContext).update(setEntry, draft: editDraft)
            editDrafts[setEntry.id] = .savedValues(from: setEntry)
            return true
        } catch {
            errorTitle = "セットを更新できませんでした"
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func deleteSet(_ setEntry: SetEntry, from exerciseEntry: ExerciseEntry) {
        do {
            try WorkoutSetService(context: modelContext).delete(setEntry, from: exerciseEntry)
            editDrafts[setEntry.id] = nil
            if focusedInput?.savedSetIdentity?.setID == setEntry.id {
                focusedInput = nil
            }
        } catch {
            errorTitle = "セットを削除できませんでした"
            errorMessage = error.localizedDescription
        }
    }

    private func requestDeletion() {
        if setEntries.isEmpty {
            deleteExercise()
        } else {
            isConfirmingDeletion = true
        }
    }

    private func deleteExercise() {
        guard let entry else { return }
        do {
            let deletedSetIDs = setEntries.map(\.id)
            try WorkoutExerciseService(context: modelContext).delete(entry, from: session)
            draftStore.removeDraft(for: entry.id, in: session.id)
            deletedSetIDs.forEach { editDrafts[$0] = nil }
            dismiss()
        } catch {
            errorTitle = "種目を削除できませんでした"
            errorMessage = error.localizedDescription
        }
    }
}

private struct PreviousWorkoutRecordView: View {
    let exerciseID: UUID
    let record: PreviousWorkoutRecordContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .accessibilityHidden(true)
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
                .accessibilityIdentifier("previous-set-row-\(exerciseID.uuidString)-\(setEntry.order)")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("previous-workout-record-\(exerciseID.uuidString)")
    }
}

private struct WorkoutSetRow: View {
    @Bindable var setEntry: SetEntry
    let exerciseEntry: ExerciseEntry

    @Binding var editDraft: SetEntryDraft
    var focusedInput: FocusState<WorkoutInputFocus?>.Binding
    let onDelete: () -> Void

    var body: some View {
        WorkoutSetColumns {
            Text(WorkoutSetDisplayFormatter.setNumber(setEntry.order + 1))
                .accessibilityLabel("セット \(setEntry.order + 1)")
        } weight: {
            HStack(spacing: 4) {
                TextField("重量", text: $editDraft.weight, prompt: Text("0"))
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .submitLabel(.next)
                    .accessibilityIdentifier("saved-set-weight-input-\(setEntry.id.uuidString)")
                    .accessibilityLabel("セット \(setEntry.order + 1)の重量、kg")
                    .focused(focusedInput, equals: savedWeightFocus)
                    .onSubmit { focusedInput.wrappedValue = savedRepsFocus }
                Text("kg")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        } reps: {
            TextField("回数", text: $editDraft.reps, prompt: Text("0"))
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .keyboardType(.numberPad)
                .submitLabel(.next)
                .accessibilityIdentifier("saved-set-reps-input-\(setEntry.id.uuidString)")
                .accessibilityLabel("セット \(setEntry.order + 1)の回数")
                .focused(focusedInput, equals: savedRepsFocus)
        }
        .textFieldStyle(.roundedBorder)
        .swipeActions {
            Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var savedWeightFocus: WorkoutInputFocus {
        .savedWeight(exerciseID: exerciseEntry.id, setID: setEntry.id)
    }

    private var savedRepsFocus: WorkoutInputFocus {
        .savedReps(exerciseID: exerciseEntry.id, setID: setEntry.id)
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

    func savedSetToCommit(whenMovingTo nextInput: WorkoutInputFocus?) -> SavedSetIdentity? {
        guard
            let savedSetIdentity,
            nextInput?.savedSetIdentity != savedSetIdentity
        else { return nil }
        return savedSetIdentity
    }

    func nextInput(savedSetIDs: [UUID], draftExerciseID: UUID) -> WorkoutInputFocus? {
        switch self {
        case .draftWeight(let exerciseID):
            .draftReps(exerciseID: exerciseID)
        case .savedWeight(let exerciseID, let setID):
            .savedReps(exerciseID: exerciseID, setID: setID)
        case .savedReps(let exerciseID, let setID):
            if let index = savedSetIDs.firstIndex(of: setID), savedSetIDs.indices.contains(index + 1) {
                .savedWeight(exerciseID: exerciseID, setID: savedSetIDs[index + 1])
            } else {
                .draftWeight(exerciseID: draftExerciseID)
            }
        case .draftReps:
            .draftWeight(exerciseID: draftExerciseID)
        }
    }

    func isDraftReps(exerciseID: UUID) -> Bool {
        self == .draftReps(exerciseID: exerciseID)
    }
}

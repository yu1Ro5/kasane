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

    @State private var pendingDraft = SetEntryDraft()
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
        List {
            Section("今回の記録") {
                WorkoutSetColumnHeader()
                if let entry {
                    ForEach(setEntries) { setEntry in
                        WorkoutSetRow(
                            setEntry: setEntry,
                            exerciseEntry: entry,
                            editDraft: editDraftBinding(for: setEntry),
                            focusedInput: $focusedInput
                        )
                    }
                }
                draftRow

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
                    .accessibilityIdentifier("add-set-button-\(inputIdentity.uuidString)")
                    .disabled(draft.wrappedValue.values() == nil || isSaving)
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
                Spacer()
                if focusedInput?.nextInput != nil {
                    Button("次へ") { focusedInput = focusedInput?.nextInput }
                } else {
                    Button("完了") { focusedInput = nil }
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
        .onDisappear { focusedInput = nil }
    }

    private var inputIdentity: UUID {
        entry?.id ?? exercise.id
    }

    private var draft: Binding<SetEntryDraft> {
        guard let entry else { return $pendingDraft }
        return Binding(
            get: { draftStore.draft(for: entry.id, in: session.id) },
            set: { draftStore.update($0, for: entry.id, in: session.id) }
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

    private func editDraftBinding(for setEntry: SetEntry) -> Binding<SetEntryDraft> {
        Binding(
            get: { editDrafts[setEntry.id] ?? .savedValues(from: setEntry) },
            set: { editDrafts[setEntry.id] = $0 }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func addSet() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
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
                    draft: pendingDraft,
                    for: exercise,
                    in: session
                )
                pendingDraft = SetEntryDraft()
            }
            focusedInput = .draftWeight(exerciseID: focusedEntry.id)
        } catch {
            errorTitle = "セットを保存できませんでした"
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
        guard editDraft.hasChanges(from: setEntry) else { return }
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

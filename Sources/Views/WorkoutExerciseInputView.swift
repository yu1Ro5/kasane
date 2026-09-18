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

    private var repSuggestions: [Int] {
        var workouts: [RepSuggestionWorkout] = []
        for workout in observedSessions where workout.endedAt != nil && workout.id != session.id {
            guard
                let exerciseEntry = workout.exerciseEntries.first(where: {
                    $0.exercise?.id == exercise.id
                })
            else { continue }
            workouts.append(
                RepSuggestionWorkout(
                    sessionID: workout.id,
                    startedAt: workout.startedAt,
                    endedAt: workout.endedAt,
                    exerciseID: exercise.id,
                    reps: exerciseEntry.setEntries.map(\.reps)
                )
            )
            if workouts.count == 20 { break }
        }
        return RepSuggestionProvider.suggestions(
            for: exercise.id,
            currentSessionID: session.id,
            workouts: workouts
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

                    Button {
                        addSet(using: proxy)
                    } label: {
                        Label("セットを追加", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                        //                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
                        if focusedInput?.isReps == true {
                            ForEach(repSuggestions, id: \.self) { reps in
                                Button("\(reps)") { applyRepSuggestion(reps) }
                                    .font(.caption)
                                    .accessibilityLabel("\(reps)回")
                                    .accessibilityIdentifier("rep-suggestion-\(reps)")
                            }
                        }
                        Spacer()
                        Button("次へ") { advanceFocus(using: proxy) }
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
        WorkoutEditableSetRow(
            setNumber: (setEntries.map(\.order).max() ?? -1) + 2,
            draft: draft,
            focusedInput: $focusedInput,
            weightFocus: .draftWeight(exerciseID: inputIdentity),
            repsFocus: .draftReps(exerciseID: inputIdentity),
            emphasizesDraft: true,
            weightIdentifier: "draft-weight-input-\(inputIdentity.uuidString)",
            repsIdentifier: "draft-reps-input-\(inputIdentity.uuidString)"
        )
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
        }
        .padding(.vertical, 2)
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
        let entryIDBeforeCommit = entry?.id
        let draftToCommit = draft.wrappedValue
        isSaving = true
        do {
            guard
                let focusedEntry = try WorkoutExerciseService(context: modelContext)
                    .commitCurrentSetIfNeeded(
                        draft: draftToCommit,
                        for: exercise,
                        in: session
                    )
            else {
                isSaving = false
                return
            }
            draftStore.removeCommittedDraft(
                for: exercise.id,
                entryIDBeforeCommit: entryIDBeforeCommit,
                in: session.id
            )
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

    private func applyRepSuggestion(_ reps: Int) {
        guard let focusedInput else { return }
        switch focusedInput {
        case .draftReps(let exerciseID) where exerciseID == inputIdentity:
            var updatedDraft = draft.wrappedValue
            updatedDraft.reps = String(reps)
            draft.wrappedValue = updatedDraft
        case .savedReps(let exerciseID, let setID) where exerciseID == inputIdentity:
            guard let setEntry = setEntries.first(where: { $0.id == setID }) else { return }
            var updatedDraft = editDrafts[setID] ?? .savedValues(from: setEntry)
            updatedDraft.reps = String(reps)
            editDrafts[setID] = updatedDraft
        case .draftWeight, .savedWeight, .draftReps, .savedReps:
            return
        }
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
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
        WorkoutEditableSetRow(
            setNumber: setEntry.order + 1,
            draft: $editDraft,
            focusedInput: focusedInput,
            weightFocus: savedWeightFocus,
            repsFocus: savedRepsFocus,
            emphasizesDraft: false,
            weightIdentifier: "saved-set-weight-input-\(setEntry.id.uuidString)",
            repsIdentifier: "saved-set-reps-input-\(setEntry.id.uuidString)"
        )
        .padding(.vertical, 2)
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

    var isReps: Bool {
        switch self {
        case .draftReps, .savedReps:
            true
        case .draftWeight, .savedWeight:
            false
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

@MainActor
private struct WorkoutExerciseInputPreview: View {
    @State private var fixture = WorkoutExerciseInputPreviewFixture()

    var body: some View {
        NavigationStack {
            WorkoutExerciseInputView(
                session: fixture.session,
                exercise: fixture.exercise,
                draftStore: fixture.draftStore
            )
        }
        .modelContainer(fixture.container)
    }
}

/// ワークアウト入力画面のPreviewで使う、保存済みセットと前回記録を含む固定データ。
@MainActor
private final class WorkoutExerciseInputPreviewFixture {
    let container: ModelContainer
    let session: WorkoutSession
    let exercise: Exercise
    let draftStore = WorkoutDraftStore()

    init() {
        do {
            container = try ModelContainer(
                for: WorkoutSession.self,
                Exercise.self,
                ExerciseEntry.self,
                SetEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Preview用のSwiftDataコンテナを作成できませんでした: \(error)")
        }

        exercise = Exercise(name: "ラットプルダウン", primaryBodyPart: .back)
        session = WorkoutSession(startedAt: .now)
        let currentEntry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        let previousSession = WorkoutSession(
            startedAt: .now.addingTimeInterval(-86_400 * 3),
            endedAt: .now.addingTimeInterval(-86_400 * 3 + 3_600)
        )
        let previousEntry = ExerciseEntry(
            workoutSession: previousSession,
            exercise: exercise,
            order: 0
        )

        let context = container.mainContext
        context.insert(session)
        context.insert(previousSession)
        context.insert(exercise)
        context.insert(currentEntry)
        context.insert(previousEntry)
        context.insert(SetEntry(exerciseEntry: currentEntry, order: 0, weightKg: 40, reps: 10))
        context.insert(SetEntry(exerciseEntry: currentEntry, order: 1, weightKg: 40, reps: 10))
        context.insert(SetEntry(exerciseEntry: currentEntry, order: 2, weightKg: 42.5, reps: 8))
        context.insert(SetEntry(exerciseEntry: previousEntry, order: 0, weightKg: 40, reps: 10))
        context.insert(SetEntry(exerciseEntry: previousEntry, order: 1, weightKg: 40, reps: 10))
        context.insert(SetEntry(exerciseEntry: previousEntry, order: 2, weightKg: 42.5, reps: 8))

        do {
            try context.save()
        } catch {
            fatalError("Preview用データを保存できませんでした: \(error)")
        }

        draftStore.update(
            SetEntryDraft(weight: "45", reps: "10"),
            for: currentEntry.id,
            in: session.id
        )
    }
}

#Preview("入力") {
    WorkoutExerciseInputPreview()
}

#Preview("入力（Dark）") {
    WorkoutExerciseInputPreview()
        .preferredColorScheme(.dark)
}

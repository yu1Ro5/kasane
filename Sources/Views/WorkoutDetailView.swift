import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @Query(sort: \ExerciseEntry.order) private var observedExerciseEntries: [ExerciseEntry]
    @Query(sort: \SetEntry.order) private var observedSetEntries: [SetEntry]
    @State private var isEditing = false
    @State private var editDraft: WorkoutHistoryEditDraft
    @State private var isShowingExercisePicker = false
    @State private var isConfirmingDiscard = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(session: WorkoutSession) {
        self.session = session
        _editDraft = State(initialValue: WorkoutHistoryEditDraft(session: session))
    }

    private var content: WorkoutDetailContent {
        WorkoutDetailContent(
            session: session,
            exerciseEntries: observedExerciseEntries.filter { $0.workoutSession?.id == session.id },
            setEntries: observedSetEntries
        )
    }

    var body: some View {
        Group {
            if isEditing {
                WorkoutHistoryEditContent(
                    content: content,
                    draft: $editDraft
                )
            } else {
                WorkoutDetailReadContent(content: content)
            }
        }
        .navigationTitle("ワークアウト詳細")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .interactiveDismissDisabled(isEditing && editDraft.hasChanges)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") { requestDiscard() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("種目を追加", systemImage: "plus") {
                        isShowingExercisePicker = true
                    }
                    Button("保存", systemImage: "checkmark") { save() }
                        .disabled(!editDraft.hasChanges || isSaving)
                }
            } else if session.endedAt != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("編集", systemImage: "pencil") { startEditing() }
                }
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            ExercisePickerView(
                selectedExerciseIDs: editDraft.selectedExerciseIDs,
                onSelect: addExercise
            )
        }
        .confirmationDialog("変更を破棄しますか？", isPresented: $isConfirmingDiscard) {
            Button("破棄する", role: .destructive) { finishEditing() }
            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("保存していない変更は失われます。")
        }
        .alert("変更を保存できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func startEditing() {
        editDraft = WorkoutHistoryEditDraft(session: session)
        isEditing = true
    }

    private func addExercise(_ exercise: Exercise) throws {
        try editDraft.addExercise(exercise)
    }

    private func requestDiscard() {
        if editDraft.hasChanges {
            isConfirmingDiscard = true
        } else {
            finishEditing()
        }
    }

    private func finishEditing() {
        isShowingExercisePicker = false
        isEditing = false
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try WorkoutHistoryEditService(context: modelContext).save(editDraft, to: session)
            finishEditing()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WorkoutDetailReadContent: View {
    let content: WorkoutDetailContent

    var body: some View {
        List {
            WorkoutDetailHeader(content: content)

            ForEach(content.exercises) { exercise in
                Section(exercise.name) {
                    WorkoutSetColumnHeader()

                    ForEach(exercise.sets) { set in
                        WorkoutSetColumns {
                            Text(WorkoutSetDisplayFormatter.setNumber(set.number))
                        } weight: {
                            WorkoutWeightText(weightKg: set.weightKg)
                        } reps: {
                            Text(WorkoutSetDisplayFormatter.reps(set.reps))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("workout-detail-view")
    }
}

struct WorkoutDetailHeader: View {
    let content: WorkoutDetailContent

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(content.startedAt, format: .dateTime.year().month().day())
                    .font(.title2.bold())
                HStack(spacing: 8) {
                    Text(content.startedAt, format: .dateTime.hour().minute())
                    Text("〜")
                    if let endedAt = content.endedAt {
                        Text(endedAt, format: .dateTime.hour().minute())
                    } else {
                        Text("--")
                    }
                }
                Text(content.durationText)
                    .font(.headline)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    let session = WorkoutSession(startedAt: .now, endedAt: .now.addingTimeInterval(3_120))
    NavigationStack {
        WorkoutDetailView(session: session)
    }
}

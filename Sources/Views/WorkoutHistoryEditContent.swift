import SwiftUI

struct WorkoutHistoryEditContent: View {
    let content: WorkoutDetailContent
    @Binding var draft: WorkoutHistoryEditDraft
    @FocusState private var focusedInput: WorkoutHistoryEditFocus?

    var body: some View {
        List {
            WorkoutDetailHeader(content: content)

            if draft.exercises.isEmpty {
                ContentUnavailableView(
                    "種目がありません",
                    systemImage: "dumbbell",
                    description: Text("種目とセットを追加してから保存してください。")
                )
            } else {
                ForEach($draft.exercises) { $exercise in
                    WorkoutHistoryEditExerciseSection(
                        exercise: $exercise,
                        focusedInput: $focusedInput,
                        onDeleteExercise: { draft.deleteExercise(id: exercise.id) },
                        onAddSet: { draft.addSet(to: exercise.id) },
                        onDeleteSet: { setID in
                            draft.deleteSet(id: setID, from: exercise.id)
                        }
                    )
                }
            }
        }
        .accessibilityIdentifier("workout-detail-edit-mode")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focusedInput = nil }
            }
        }
    }
}

private struct WorkoutHistoryEditExerciseSection: View {
    @Binding var exercise: WorkoutHistoryEditDraft.ExerciseDraft
    var focusedInput: FocusState<WorkoutHistoryEditFocus?>.Binding
    let onDeleteExercise: () -> Void
    let onAddSet: () -> Void
    let onDeleteSet: (UUID) -> Void

    var body: some View {
        Section {
            WorkoutSetColumnHeader()
            ForEach($exercise.sets) { $setDraft in
                WorkoutSetColumns {
                    Text(WorkoutSetDisplayFormatter.setNumber(setNumber(for: setDraft.id)))
                } weight: {
                    HStack(spacing: 4) {
                        TextField("重量", text: $setDraft.values.weight, prompt: Text("0"))
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .accessibilityIdentifier(
                                "history-edit-weight-input-\(exerciseAccessibilityKey)-\(setDraft.id.uuidString)"
                            )
                            .keyboardType(.decimalPad)
                            .focused(focusedInput, equals: .weight(setID: setDraft.id))
                        Text("kg")
                    }
                } reps: {
                    TextField("回数", text: $setDraft.values.reps, prompt: Text("0"))
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .accessibilityIdentifier(
                            "history-edit-reps-input-\(exerciseAccessibilityKey)-\(setDraft.id.uuidString)"
                        )
                        .keyboardType(.numberPad)
                        .focused(focusedInput, equals: .reps(setID: setDraft.id))
                }
                .swipeActions {
                    Button("削除", systemImage: "trash", role: .destructive) {
                        onDeleteSet(setDraft.id)
                    }
                }
            }

            Button("セットを追加", systemImage: "plus", action: onAddSet)
                .accessibilityIdentifier("history-edit-add-set-\(exerciseAccessibilityKey)")
        } header: {
            HStack {
                Text(exercise.exerciseNameSnapshot)
                Spacer()
                Menu {
                    Button("種目を削除", systemImage: "trash", role: .destructive) {
                        onDeleteExercise()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        } footer: {
            if exercise.sets.isEmpty {
                Text("この種目には1件以上のセットが必要です。")
                    .foregroundStyle(.red)
            }
        }
    }

    private func setNumber(for id: UUID) -> Int {
        (exercise.sets.firstIndex(where: { $0.id == id }) ?? 0) + 1
    }

    private var exerciseAccessibilityKey: String {
        (exercise.exerciseID ?? exercise.id).uuidString
    }
}

private enum WorkoutHistoryEditFocus: Hashable {
    case weight(setID: UUID)
    case reps(setID: UUID)
}

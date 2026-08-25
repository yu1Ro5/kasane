import SwiftData
import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession

    @State private var isShowingPicker = false
    @State private var isConfirmingDiscard = false
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
                        Section {
                            DraftSetRow()
                        } header: {
                            HStack {
                                Text(entry.exerciseNameSnapshot)
                                Spacer()
                                Menu {
                                    Button("種目を削除", systemImage: "trash", role: .destructive) {
                                        requestDeletion(of: entry)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("ワークアウト")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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

private struct DraftSetRow: View {
    @State private var weight = ""
    @State private var reps = ""

    var body: some View {
        HStack(spacing: 12) {
            Text("Set 1")
            TextField("重量 (kg)", text: $weight)
                .keyboardType(.decimalPad)
            TextField("回数", text: $reps)
                .keyboardType(.numberPad)
        }
        .textFieldStyle(.roundedBorder)
    }
}

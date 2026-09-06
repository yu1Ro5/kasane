import SwiftData
import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let selectedExerciseIDs: Set<UUID>
    let onSelect: (Exercise) throws -> Void

    @State private var searchText = ""
    @State private var errorMessage: String?

    private var filteredExercises: [Exercise] {
        exercises.filter {
            $0.isSelectable && (searchText.isEmpty || $0.name.localizedStandardContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredExercises.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                            let items = filteredExercises.filter { $0.bodyPart == bodyPart }
                            if !items.isEmpty {
                                Section(bodyPart.displayName) {
                                    ForEach(items) { exercise in
                                        exerciseButton(exercise)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "種目名を検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") { dismiss() }
                }
            }
            .alert("種目を追加できませんでした", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました。")
            }
        }
    }

    private func exerciseButton(_ exercise: Exercise) -> some View {
        let isSelected = selectedExerciseIDs.contains(exercise.id)
        return Button {
            do {
                try onSelect(exercise)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            HStack {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .disabled(isSelected)
        .accessibilityValue(isSelected ? "追加済み" : "")
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

import SwiftData
import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let selectedExerciseIDs: Set<UUID>
    let onSelect: (Exercise) throws -> Void

    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var expandedBodyParts: Set<BodyPart> = []

    private static let bodyPartDisplayOrder: [BodyPart] = [
        .chest,
        .back,
        .shoulders,
        .arms,
        .legs,
        .core,
        .fullBody,
        .other,
    ]

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
                        if searchText.isEmpty {
                            ForEach(Self.bodyPartDisplayOrder, id: \.self) { bodyPart in
                                let items = exercises(for: bodyPart)
                                if !items.isEmpty {
                                    Section {
                                        bodyPartHeader(bodyPart, exerciseCount: items.count)

                                        if expandedBodyParts.contains(bodyPart) {
                                            ForEach(items) { exercise in
                                                exerciseButton(exercise)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            ForEach(filteredExercises) { exercise in
                                exerciseButton(exercise)
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

    private func exercises(for bodyPart: BodyPart) -> [Exercise] {
        exercises.filter { $0.isSelectable && $0.bodyPart == bodyPart }
    }

    private func bodyPartHeader(_ bodyPart: BodyPart, exerciseCount: Int) -> some View {
        let isExpanded = expandedBodyParts.contains(bodyPart)
        return Button {
            withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)) {
                toggle(bodyPart)
            }
        } label: {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
                Text(bodyPart.displayName)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(exerciseCount, format: .number)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bodyPart.displayName)、\(exerciseCount)種目")
        .accessibilityValue(isExpanded ? "展開中" : "折りたたみ中")
        .accessibilityHint(isExpanded ? "ダブルタップで折りたたみます" : "ダブルタップで展開します")
    }

    private func toggle(_ bodyPart: BodyPart) {
        if expandedBodyParts.contains(bodyPart) {
            expandedBodyParts.remove(bodyPart)
        } else {
            expandedBodyParts.insert(bodyPart)
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

import SwiftData
import SwiftUI

struct ExerciseManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var filter: ExerciseListFilter = .active
    @State private var isAdding = false
    @State private var editingExercise: Exercise?
    @State private var archivingExercise: Exercise?
    @State private var isConfirmingArchive = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private var visibleExercises: [Exercise] { exercises.filter { filter.includes($0) } }

    var body: some View {
        List {
            if visibleExercises.isEmpty {
                ContentUnavailableView(filter.emptyMessage, systemImage: "line.3.horizontal.decrease.circle")
                    .listRowBackground(Color.clear)
            }
            ForEach(BodyPart.allCases, id: \.self) { part in
                let items = visibleExercises.filter { $0.bodyPart == part }
                if !items.isEmpty {
                    Section(part.displayName) {
                        ForEach(items) { exercise in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text(part.displayName).font(.caption).foregroundStyle(.secondary)
                                    if filter == .all && exercise.isArchived {
                                        Text("アーカイブ済み")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Menu {
                                    Button("編集", systemImage: "pencil") { editingExercise = exercise }
                                    if exercise.isArchived {
                                        Button("アーカイブ解除", systemImage: "arrow.uturn.backward") {
                                            changeArchiveState(for: exercise, to: false)
                                        }
                                    } else {
                                        Button("アーカイブ", systemImage: "archivebox", role: .destructive) {
                                            archivingExercise = exercise
                                            isConfirmingArchive = true
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .accessibilityLabel("\(exercise.name)の操作")
                                .accessibilityIdentifier("exercise-actions-\(exercise.id.uuidString)")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("種目管理")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    ForEach(ExerciseListFilter.allCases, id: \.self) { option in
                        Button {
                            filter = option
                        } label: {
                            if filter == option {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("種目を絞り込む：\(filter.rawValue)")
                .accessibilityIdentifier("exercise-filter-button")
                Button("種目を追加", systemImage: "plus") { isAdding = true }
                    .accessibilityIdentifier("exercise-add-button")
            }
        }
        .sheet(isPresented: $isAdding) {
            ExerciseFormSheet(onSaved: { filter = .active })
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseFormSheet(exercise: exercise)
        }
        .confirmationDialog("\(archivingExercise?.name ?? "種目")をアーカイブしますか？", isPresented: $isConfirmingArchive, titleVisibility: .visible) {
            Button("アーカイブ", role: .destructive) {
                if let exercise = archivingExercise { changeArchiveState(for: exercise, to: true) }
                archivingExercise = nil
            }
            Button("キャンセル", role: .cancel) { archivingExercise = nil }
        }
        .alert("種目を更新できませんでした", isPresented: $isShowingError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func changeArchiveState(for exercise: Exercise, to archived: Bool) {
        do {
            try ExerciseArchiveService().setArchived(archived, exerciseID: exercise.id, in: context.container)
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }
}

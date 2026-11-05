import SwiftData
import SwiftUI

/// Fields can also be used with a draft initialized from an existing exercise.
struct ExerciseFormFields: View {
    @Bindable var draft: ExerciseFormViewModel

    var body: some View {
        TextField("種目名", text: $draft.name)
            .accessibilityIdentifier("exercise-name-field")
        Picker("主な部位", selection: $draft.bodyPart) {
            ForEach(BodyPart.allCases, id: \.self) { part in
                Text(part.displayName).tag(part)
            }
        }
    }
}

struct ExerciseFormSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var exercises: [Exercise]
    @State private var draft: ExerciseFormViewModel
    @State private var confirmDiscard = false
    private let editingID: UUID?
    private let onSaved: (() -> Void)?

    init(exercise: Exercise? = nil, onSaved: (() -> Void)? = nil) {
        editingID = exercise?.id
        self.onSaved = onSaved
        _draft = State(initialValue: ExerciseFormViewModel(
            name: exercise?.name ?? "", bodyPart: exercise?.bodyPart ?? .other, editingID: exercise?.id))
    }

    private var otherNames: [String] {
        exercises.filter { $0.id != editingID }.map(\.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { ExerciseFormFields(draft: draft) }
                if let message = draft.validationMessage(existingNames: otherNames), !draft.name.isEmpty {
                    Section { Text(message).foregroundStyle(.secondary) }
                }
                if let error = draft.errorMessage {
                    Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("exercise-save-error") }
                }
            }
            .navigationTitle(editingID == nil ? "種目を追加" : "種目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        if draft.hasChanges { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingID == nil ? "追加" : "保存") {
                        if draft.save(in: context.container) {
                            onSaved?()
                            dismiss()
                        }
                    }
                    .disabled(draft.validationMessage(existingNames: otherNames) != nil)
                    .accessibilityIdentifier("exercise-save-button")
                }
            }
            .confirmationDialog("入力内容を破棄しますか？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("破棄する", role: .destructive) { dismiss() }
                Button("入力を続ける", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(draft.hasChanges)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }
}

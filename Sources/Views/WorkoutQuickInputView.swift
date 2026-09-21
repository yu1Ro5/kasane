import SwiftData
import SwiftUI

struct WorkoutQuickInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    @Bindable var draftStore: WorkoutDraftStore
    let exercises: [Exercise]
    @State private var viewModel: WorkoutQuickInputViewModel
    @FocusState private var isTextInputFocused: Bool
    @FocusState private var focusedInput: WorkoutQuickInputFocus?

    init(
        session: WorkoutSession,
        draftStore: WorkoutDraftStore,
        exercises: [Exercise],
        parser: any WorkoutQuickInputParsing
    ) {
        self.session = session
        self.draftStore = draftStore
        self.exercises = exercises
        _viewModel = State(initialValue: WorkoutQuickInputViewModel(parser: parser))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: viewModel.draft == nil ? 24 : 16) {
                if viewModel.draft == nil { brandHeader }
                inputCard
                if viewModel.draft != nil { reviewSection }
                if viewModel.draft == nil { noticeCard }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AIでまとめて入力")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedInput != nil {
                    Button("次へ", action: advanceFocus)
                    Spacer()
                    Button("完了") { focusedInput = nil }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.draft != nil { reviewActions }
        }
        .interactiveDismissDisabled(viewModel.isAnalyzing || viewModel.isApplying)
        .alert("AI入力を完了できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 14) {
            Text("Apple Intelligenceでワークアウトを記録")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Label("K A S A N E", systemImage: "mountain.2.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Spacer()
                Text("続ける人が、\nいちばん強い。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: viewModel.draft == nil ? 14 : 8) {
            HStack {
                Label("入力内容", systemImage: "doc.text")
                    .font(.title3.bold())
                Spacer()
                if viewModel.draft != nil {
                    Button("編集", systemImage: "pencil") { viewModel.editText() }
                        .font(.subheadline)
                }
            }
            if viewModel.draft == nil {
                TextEditor(text: $viewModel.text)
                    .focused($isTextInputFocused)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).stroke(.quaternary)
                    }
                    .accessibilityLabel("ワークアウトの自然文入力")
                    .accessibilityIdentifier("workout-ai-input-text")
                HStack {
                    Text("例: チェストプレス30kgを10回3セット。最後だけ8回。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.characterCount)/\(WorkoutQuickInputViewModel.maximumCharacterCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(viewModel.characterCount > 500 ? .red : .secondary)
                }
                if viewModel.characterCount > WorkoutQuickInputViewModel.maximumCharacterCount {
                    Label("500文字以内に短くしてください。", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button(action: analyze) {
                    HStack {
                        if viewModel.isAnalyzing { ProgressView() }
                        Text(viewModel.isAnalyzing ? "解析中…" : "Apple Intelligenceで解析")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canAnalyze)
                .accessibilityHint(
                    viewModel.characterCount > WorkoutQuickInputViewModel.maximumCharacterCount
                        ? "500文字以内に短くしてください" : "入力した文章からセットを解析します"
                )
                .accessibilityIdentifier("workout-ai-analyze-button")
            } else {
                Text(viewModel.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.subheadline)
                Label("Apple Intelligenceで解析済み", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(viewModel.draft == nil ? 18 : 14)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("入力内容を確認", systemImage: "list.bullet.rectangle")
                .font(.title2.bold())
            Text("AIが入力した下書きです。自由に追加・修正してから保存できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(exerciseBindings) { $exercise in
                exerciseCard(exercise: $exercise)
            }
            addExerciseMenu
            if let message = blockingMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("workout-ai-validation-message")
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-ai-review")
    }

    private func exerciseCard(
        exercise: Binding<WorkoutQuickInputExerciseDraft>
    ) -> some View {
        VStack(spacing: 10) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) { exerciseHeader(exercise: exercise) }
                } else {
                    HStack(alignment: .center, spacing: 8) { exerciseHeader(exercise: exercise) }
                }
            }
            if exercise.wrappedValue.sets.isEmpty {
                Text("まだセットがありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                if !dynamicTypeSize.isAccessibilitySize { WorkoutSetColumnHeader() }
                ForEach(Array(exercise.wrappedValue.sets.enumerated()), id: \.element.id) { index, set in
                    WorkoutEditableSetRow(
                        setNumber: index + 1,
                        draft: setBinding(exerciseID: exercise.wrappedValue.id, setID: set.id),
                        focusedInput: $focusedInput,
                        weightFocus: .weight(exerciseDraftID: exercise.wrappedValue.id, setID: set.id),
                        repsFocus: .reps(exerciseDraftID: exercise.wrappedValue.id, setID: set.id),
                        emphasizesDraft: true,
                        weightIdentifier: "workout-ai-weight-\(set.id.uuidString)",
                        repsIdentifier: "workout-ai-reps-\(set.id.uuidString)",
                        onDelete: { removeSet(set.id, from: exercise.wrappedValue.id) },
                        onRepsSubmit: advanceFocus
                    )
                }
            }
            Button {
                addSet(to: exercise.wrappedValue.id)
            } label: {
                Label("セットを追加", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("セットを追加")
            .accessibilityIdentifier("workout-ai-add-set-\(exercise.wrappedValue.id.uuidString)")
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.quaternary) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-ai-exercise-\(exercise.wrappedValue.id.uuidString)")
    }

    @ViewBuilder
    private func exerciseHeader(exercise: Binding<WorkoutQuickInputExerciseDraft>) -> some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .foregroundStyle(.tint)
            .frame(width: 32, height: 32)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        Menu {
            ForEach(selectableExercises) { item in
                Button(item.name) {
                    _ = viewModel.updateExercise(draftID: exercise.wrappedValue.id, to: item)
                }
                .disabled(isUsed(item.id, excluding: exercise.wrappedValue.id))
            }
        } label: {
            HStack(spacing: 4) {
                Text(resolvedName(for: exercise.wrappedValue) ?? exercise.wrappedValue.sourceName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .layoutPriority(1)
        }
        .accessibilityLabel("種目")
        .accessibilityValue(
            resolvedName(for: exercise.wrappedValue) ?? exercise.wrappedValue.sourceName
        )
        .accessibilityHint("タップして変更")
        Label(
            exercise.wrappedValue.exerciseID == nil ? "未解決" : "種目一致",
            systemImage: exercise.wrappedValue.exerciseID == nil
                ? "exclamationmark.circle" : "checkmark.circle.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(exercise.wrappedValue.exerciseID == nil ? .orange : .green)
        .fixedSize()
        if dynamicTypeSize.isAccessibilitySize {
            if exercise.wrappedValue.exerciseID == nil {
                Text("入力: \(exercise.wrappedValue.sourceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
        Button(role: .destructive) {
            clearFocus(for: exercise.wrappedValue.id)
            viewModel.removeExercise(id: exercise.wrappedValue.id)
        } label: {
            Label("種目を削除", systemImage: "trash")
        }
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
    }

    private func resolvedName(for draft: WorkoutQuickInputExerciseDraft) -> String? {
        exercises.first { $0.id == draft.exerciseID }?.name
    }

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill").font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text("保存前に必ず確認できます").font(.headline)
                Text("AIは入力を補助します。保存はまだ行われていません。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .foregroundStyle(.green)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }

    private var reviewActions: some View {
        VStack(spacing: 8) {
            Button(action: apply) {
                HStack {
                    if viewModel.isApplying { ProgressView().tint(.white) }
                    Text(viewModel.isApplying ? "追加中…" : "この内容で追加")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(blockingMessage != nil || viewModel.isApplying)
            .accessibilityHint(blockingMessage ?? "確認したセットをワークアウトへ追加します")
            .accessibilityIdentifier("workout-ai-apply-button")

            Button("テキストを修正") { viewModel.editText() }
                .font(.subheadline)
                .accessibilityIdentifier("workout-ai-edit-text-button")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private var selectableExercises: [Exercise] { exercises.filter(\.isSelectable) }

    private var addExerciseMenu: some View {
        Menu {
            ForEach(selectableExercises) { exercise in
                Button(exercise.name) { _ = viewModel.addExercise(exercise) }
                    .disabled(isUsed(exercise.id))
            }
        } label: {
            Label("種目を追加", systemImage: "plus")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("種目を追加")
        .accessibilityIdentifier("workout-ai-add-exercise-button")
    }

    private var exerciseBindings: Binding<[WorkoutQuickInputExerciseDraft]> {
        Binding(get: { viewModel.draft?.exercises ?? [] }, set: { viewModel.draft?.exercises = $0 })
    }

    private var blockingMessage: String? {
        guard let draft = viewModel.draft else { return nil }
        return viewModel.validationMessage
            ?? WorkoutQuickInputApplyService(context: modelContext).conflictMessage(
                for: draft,
                in: session,
                exercises: exercises,
                draftStore: draftStore
            )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }

    private func apply() {
        guard let draft = viewModel.draft, blockingMessage == nil else { return }
        viewModel.isApplying = true
        do {
            try WorkoutQuickInputApplyService(context: modelContext).apply(
                draft,
                to: session,
                exercises: exercises,
                draftStore: draftStore
            )
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
            viewModel.isApplying = false
        }
    }

    private func analyze() {
        isTextInputFocused = false
        Task { await viewModel.analyze(availableExercises: exercises) }
    }

    private func setBinding(exerciseID: UUID, setID: UUID) -> Binding<SetEntryDraft> {
        Binding(
            get: {
                viewModel.draft?.exercises.first(where: { $0.id == exerciseID })?
                    .sets.first(where: { $0.id == setID })?.values ?? SetEntryDraft()
            },
            set: { values in
                guard
                    let exerciseIndex = viewModel.draft?.exercises.firstIndex(where: { $0.id == exerciseID }),
                    let setIndex = viewModel.draft?.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
                else { return }
                viewModel.draft?.exercises[exerciseIndex].sets[setIndex].values = values
            }
        )
    }

    private func isUsed(_ exerciseID: UUID, excluding draftID: UUID? = nil) -> Bool {
        viewModel.draft?.exercises.contains {
            $0.id != draftID && $0.exerciseID == exerciseID
        } == true
    }

    private func addSet(to exerciseID: UUID) {
        guard let setID = viewModel.addSet(to: exerciseID) else { return }
        Task { @MainActor in
            await Task.yield()
            focusedInput = .weight(exerciseDraftID: exerciseID, setID: setID)
        }
    }

    private func removeSet(_ setID: UUID, from exerciseID: UUID) {
        if focusedInput?.setID == setID { focusedInput = nil }
        viewModel.removeSet(id: setID, from: exerciseID)
    }

    private func clearFocus(for exerciseID: UUID) {
        if focusedInput?.exerciseDraftID == exerciseID { focusedInput = nil }
    }

    private func advanceFocus() {
        guard let focusedInput else { return }
        switch focusedInput {
        case .weight(let exerciseID, let setID):
            self.focusedInput = .reps(exerciseDraftID: exerciseID, setID: setID)
        case .reps(let exerciseID, let setID):
            guard
                let sets = viewModel.draft?.exercises.first(where: { $0.id == exerciseID })?.sets,
                let index = sets.firstIndex(where: { $0.id == setID }),
                sets.indices.contains(index + 1)
            else {
                self.focusedInput = nil
                return
            }
            self.focusedInput = .weight(exerciseDraftID: exerciseID, setID: sets[index + 1].id)
        }
    }
}

private enum WorkoutQuickInputFocus: Hashable {
    case weight(exerciseDraftID: UUID, setID: UUID)
    case reps(exerciseDraftID: UUID, setID: UUID)

    var exerciseDraftID: UUID {
        switch self {
        case .weight(let exerciseDraftID, _), .reps(let exerciseDraftID, _): exerciseDraftID
        }
    }

    var setID: UUID {
        switch self {
        case .weight(_, let setID), .reps(_, let setID): setID
        }
    }
}

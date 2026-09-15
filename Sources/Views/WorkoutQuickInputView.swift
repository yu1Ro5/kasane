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
            VStack(spacing: 24) {
                brandHeader
                inputCard
                if viewModel.draft != nil { reviewSection }
                noticeCard
                actionArea
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AIでまとめて入力")
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("入力内容", systemImage: "doc.text")
                    .font(.title3.bold())
                Spacer()
                if viewModel.draft != nil {
                    Button("テキストを編集", systemImage: "pencil") { viewModel.editText() }
                        .buttonStyle(.bordered)
                }
            }
            if viewModel.draft == nil {
                TextEditor(text: $viewModel.text)
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
                Button {
                    Task { await viewModel.analyze(availableExercises: exercises) }
                } label: {
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
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
                Label("Apple Intelligenceが内容を解析しました", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("入力内容を確認", systemImage: "list.bullet.rectangle")
                .font(.title2.bold())
            Text("AIが解析した内容です。必要に応じて修正できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(exerciseBindings) { $exercise in
                exerciseCard(exercise: $exercise)
            }
            if let message = blockingMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("workout-ai-validation-message")
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityIdentifier("workout-ai-review")
    }

    private func exerciseCard(
        exercise: Binding<WorkoutQuickInputExerciseDraft>
    ) -> some View {
        VStack(spacing: 14) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) { exerciseHeader(exercise: exercise) }
                } else {
                    HStack(alignment: .top, spacing: 10) { exerciseHeader(exercise: exercise) }
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(Array(exercise.sets.wrappedValue.indices), id: \.self) { index in
                        expandedSetEditor(exercise: exercise, index: index)
                    }
                }
            } else {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Text("セット").foregroundStyle(.secondary)
                        Text("重量 (kg)").foregroundStyle(.secondary)
                        Text("回数").foregroundStyle(.secondary)
                        Color.clear.frame(width: 44)
                    }
                    ForEach(Array(exercise.sets.wrappedValue.indices), id: \.self) { index in
                        compactSetEditor(exercise: exercise, index: index)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.quaternary) }
        .accessibilityIdentifier("workout-ai-exercise-\(exercise.wrappedValue.id.uuidString)")
    }

    @ViewBuilder
    private func exerciseHeader(exercise: Binding<WorkoutQuickInputExerciseDraft>) -> some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .frame(width: 48, height: 48)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 6) {
            Text(resolvedName(for: exercise.wrappedValue) ?? exercise.wrappedValue.sourceName)
                .font(.headline)
            if exercise.wrappedValue.exerciseID == nil {
                Text("入力: \(exercise.wrappedValue.sourceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("種目", selection: exercise.exerciseID) {
                Text("種目を選択").tag(UUID?.none)
                ForEach(selectableExercises) { item in
                    Text(item.name).tag(Optional(item.id))
                }
            }
            .labelsHidden()
            Label(
                exercise.wrappedValue.exerciseID == nil ? "未解決" : "種目一致",
                systemImage: exercise.wrappedValue.exerciseID == nil
                    ? "exclamationmark.circle" : "checkmark.circle.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(exercise.wrappedValue.exerciseID == nil ? .orange : .green)
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
        Button(role: .destructive) {
            viewModel.removeExercise(id: exercise.wrappedValue.id)
        } label: {
            Label("種目を削除", systemImage: "trash")
        }
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
    }

    private func compactSetEditor(
        exercise: Binding<WorkoutQuickInputExerciseDraft>,
        index: Int
    ) -> some View {
        let setID = exercise.sets.wrappedValue[index].id
        return GridRow {
            Text("\(index + 1)").monospacedDigit()
            TextField("重量", text: exercise.sets[index].values.weight)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("セット\(index + 1)の重量kg")
            TextField("回数", text: exercise.sets[index].values.reps)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("セット\(index + 1)の回数")
            Button(role: .destructive) {
                viewModel.removeSet(id: setID, from: exercise.wrappedValue.id)
            } label: {
                Image(systemName: "minus.circle")
            }
            .accessibilityLabel("セット\(index + 1)を削除")
            .frame(width: 44, height: 44)
        }
    }

    private func expandedSetEditor(
        exercise: Binding<WorkoutQuickInputExerciseDraft>,
        index: Int
    ) -> some View {
        let setID = exercise.sets.wrappedValue[index].id
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("セット \(index + 1)").font(.headline)
                Spacer()
                Button(role: .destructive) {
                    viewModel.removeSet(id: setID, from: exercise.wrappedValue.id)
                } label: {
                    Label("セット\(index + 1)を削除", systemImage: "minus.circle")
                }
            }
            LabeledContent("重量 (kg)") {
                TextField("重量", text: exercise.sets[index].values.weight)
                    .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("セット\(index + 1)の重量kg")
            }
            LabeledContent("回数") {
                TextField("回数", text: exercise.sets[index].values.reps)
                    .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("セット\(index + 1)の回数")
            }
        }
        .padding(.vertical, 4)
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

    @ViewBuilder private var actionArea: some View {
        if viewModel.draft != nil {
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
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("workout-ai-edit-text-button")
        }
    }

    private var selectableExercises: [Exercise] { exercises.filter(\.isSelectable) }

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
}

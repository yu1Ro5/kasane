import SwiftUI

/// 保存先に依存せず、セット番号・重量・回数を編集する共通行。
struct WorkoutEditableSetRow<FocusValue: Hashable>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let setNumber: Int
    @Binding var draft: SetEntryDraft
    var focusedInput: FocusState<FocusValue?>.Binding
    let weightFocus: FocusValue
    let repsFocus: FocusValue
    let emphasizesDraft: Bool
    let weightIdentifier: String
    let repsIdentifier: String
    var onDelete: (() -> Void)?
    var onRepsSubmit: (() -> Void)?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("セット \(setNumber)").font(.headline)
                        Spacer()
                        deleteButton
                    }
                    LabeledContent("重量 (kg)") { weightField }
                    LabeledContent("回数") { repsField }
                }
            } else {
                HStack(spacing: 8) {
                    WorkoutSetColumns {
                        Text(WorkoutSetDisplayFormatter.setNumber(setNumber))
                            .fontWeight(.medium)
                            .accessibilityLabel("セット \(setNumber)")
                    } weight: {
                        HStack(spacing: 4) {
                            weightField
                            Text("kg")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    } reps: {
                        repsField
                    }
                    if onDelete != nil { deleteButton }
                }
            }
        }
    }

    private var weightField: some View {
        TextField("重量", text: $draft.weight, prompt: Text("0"))
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .keyboardType(.decimalPad)
            .submitLabel(.next)
            .accessibilityIdentifier(weightIdentifier)
            .accessibilityLabel("セット\(setNumber)の重量kg")
            .focused(focusedInput, equals: weightFocus)
            .onSubmit { focusedInput.wrappedValue = repsFocus }
            .workoutSetInputStyle(
                isFocused: focusedInput.wrappedValue == weightFocus,
                emphasizesDraft: emphasizesDraft
            )
    }

    private var repsField: some View {
        TextField("回数", text: $draft.reps, prompt: Text("0"))
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .keyboardType(.numberPad)
            .submitLabel(.next)
            .accessibilityIdentifier(repsIdentifier)
            .accessibilityLabel("セット\(setNumber)の回数")
            .focused(focusedInput, equals: repsFocus)
            .onSubmit { onRepsSubmit?() }
            .workoutSetInputStyle(
                isFocused: focusedInput.wrappedValue == repsFocus,
                emphasizesDraft: emphasizesDraft
            )
    }

    @ViewBuilder
    private var deleteButton: some View {
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .accessibilityLabel("セット\(setNumber)を削除")
            .frame(minWidth: 44, minHeight: 44)
        }
    }
}

extension View {
    /// セット入力欄を表形式に保ちつつ、現在の入力位置を視覚的に示す。
    func workoutSetInputStyle(isFocused: Bool, emphasizesDraft: Bool) -> some View {
        padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                isFocused
                    ? Color.accentColor.opacity(0.12)
                    : emphasizesDraft ? Color(.secondarySystemBackground) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isFocused
                            ? Color.accentColor
                            : Color.secondary.opacity(emphasizesDraft ? 0.25 : 0.16),
                        lineWidth: isFocused ? 2 : 1
                    )
            }
            .shadow(color: isFocused ? Color.accentColor.opacity(0.16) : .clear, radius: 3, y: 1)
    }
}

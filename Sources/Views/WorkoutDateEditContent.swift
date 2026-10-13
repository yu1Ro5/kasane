import SwiftUI

struct WorkoutDateEditContent: View {
    @Binding var draft: WorkoutDateEditDraft

    var body: some View {
        List {
            Section("日時") {
                DatePicker("開始日時", selection: $draft.startedAt, displayedComponents: [.date, .hourAndMinute])
                    .accessibilityIdentifier("workout-start-date-input")
                DatePicker("終了日時", selection: $draft.endedAt, displayedComponents: [.date, .hourAndMinute])
                    .accessibilityIdentifier("workout-end-date-input")
            }
            Section {
                LabeledContent("トレーニング時間", value: draft.durationText)
                    .accessibilityIdentifier("workout-date-duration")
                if let message = draft.validationMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("workout-date-validation")
                }
            }
        }
        .accessibilityIdentifier("workout-date-edit-view")
    }
}

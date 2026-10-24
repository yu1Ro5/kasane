import SwiftUI

struct WorkoutEndReminderSheet: View {
    let session: WorkoutSession
    let finishBlockingMessage: String?
    let onFinish: (Date) async throws -> Void
    let onContinue: () async -> Void
    let onSessionEnded: () -> Void

    @State private var endedAt: Date
    @State private var latestAllowedDate: Date
    @State private var isFinishing = false
    @State private var isConfirmingFinish = false
    @State private var errorMessage: String?

    init(
        session: WorkoutSession,
        finishBlockingMessage: String?,
        now: Date = .now,
        onFinish: @escaping (Date) async throws -> Void,
        onContinue: @escaping () async -> Void,
        onSessionEnded: @escaping () -> Void
    ) {
        self.session = session
        self.finishBlockingMessage = finishBlockingMessage
        self.onFinish = onFinish
        self.onContinue = onContinue
        self.onSessionEnded = onSessionEnded
        _endedAt = State(initialValue: now)
        _latestAllowedDate = State(initialValue: now)
    }

    private var validationMessage: String? {
        WorkoutEndDateValidation.message(
            startedAt: session.startedAt,
            endedAt: endedAt,
            latestAllowedDate: latestAllowedDate
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text(
                            "ワークアウトが長時間続いています。記録を確認して、終了するか続けるか選んでください。"
                        )
                    } icon: {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundStyle(.tint)
                    }
                    .accessibilityIdentifier("workout-end-reminder-message")
                }

                Section("記録") {
                    LabeledContent(
                        "開始日時",
                        value: session.startedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    .accessibilityIdentifier("workout-end-reminder-started-at")

                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        LabeledContent(
                            "現在までの経過時間",
                            value: elapsedTimeText(at: context.date)
                        )
                    }
                    .accessibilityIdentifier("workout-end-reminder-elapsed-time")
                }

                Section("終了日時") {
                    DatePicker(
                        "終了日時",
                        selection: $endedAt,
                        in: session.startedAt...latestAllowedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("workout-end-reminder-end-date")

                    if let message = validationMessage ?? finishBlockingMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("workout-end-reminder-validation")
                    }
                }

                Section {
                    Button {
                        latestAllowedDate = .now
                        isConfirmingFinish =
                            validationMessage == nil
                            && finishBlockingMessage == nil
                    } label: {
                        Text("終了日時を指定して終了")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isFinishing || validationMessage != nil || finishBlockingMessage != nil
                    )
                    .accessibilityIdentifier("workout-end-reminder-finish-button")

                    Button {
                        Task { await onContinue() }
                    } label: {
                        Text("トレーニングを続ける")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("workout-end-reminder-continue-button")
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("終了忘れの確認")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
            .confirmationDialog(
                "この日時でワークアウトを終了しますか？",
                isPresented: $isConfirmingFinish
            ) {
                Button("終了して保存") {
                    Task { await finish() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(endedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .alert("ワークアウトを終了できませんでした", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました。")
            }
            .onChange(of: session.endedAt) { _, endedAt in
                if endedAt != nil {
                    onSessionEnded()
                }
            }
        }
        .accessibilityIdentifier("workout-end-reminder-sheet")
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func elapsedTimeText(at date: Date) -> String {
        let totalMinutes = max(0, Int(date.timeIntervalSince(session.startedAt) / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

    private func finish() async {
        guard !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }
        do {
            try await onFinish(endedAt)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

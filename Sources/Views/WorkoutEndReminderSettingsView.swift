import SwiftData
import SwiftUI
import UIKit

struct WorkoutEndReminderSettingsView: View {
    @Environment(WorkoutEndReminderCoordinator.self) private var reminderCoordinator
    @Environment(\.openURL) private var openURL
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt == nil },
        sort: \WorkoutSession.startedAt
    ) private var activeSessions: [WorkoutSession]

    var body: some View {
        List {
            Section {
                Toggle(
                    "終了忘れ通知",
                    isOn: Binding(
                        get: { reminderCoordinator.notificationsEnabled },
                        set: { enabled in
                            Task {
                                await reminderCoordinator.setNotificationsEnabled(
                                    enabled,
                                    activeSessions: activeSessions
                                )
                            }
                        }
                    )
                )
                .accessibilityIdentifier("workout-end-reminder-toggle")

                LabeledContent("通知の状態", value: reminderCoordinator.notificationStatusText)
                    .accessibilityIdentifier("workout-end-reminder-status")
            } footer: {
                Text(
                    "ワークアウト開始から6時間後と8時間後に、終了忘れを最大2回お知らせします。オフでもアプリ内の確認は表示されます。"
                )
            }

            if reminderCoordinator.notificationsEnabled,
                reminderCoordinator.authorizationStatus == .denied
            {
                Section {
                    Button("iPhoneの設定を開く") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        openURL(url)
                    }
                    .accessibilityIdentifier("workout-end-reminder-open-settings-button")
                } footer: {
                    Text(
                        "通知を受け取るには、iPhoneの設定でKASANEの通知を許可してください。"
                    )
                }
            }
        }
        .navigationTitle("終了忘れ通知")
        .task { await reminderCoordinator.refreshAuthorizationStatus() }
        .alert("通知を設定できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reminderCoordinator.notificationErrorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { reminderCoordinator.notificationErrorMessage != nil },
            set: { if !$0 { reminderCoordinator.notificationErrorMessage = nil } }
        )
    }
}

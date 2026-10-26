import SwiftUI

/// アプリ情報と公開中のサポート情報への導線を表示する画面。
struct AboutView: View {
    @Environment(WorkoutEndReminderCoordinator.self) private var reminderCoordinator
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KASANE")
                        .font(.title2.bold())
                    Text("Version \(AppVersion.current)")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("about-version")
                }
            }

            Section {
                if let supportURL = AppLinks.support {
                    AboutLink(title: "サポート", destination: supportURL)
                }
                if let privacyPolicyURL = AppLinks.privacyPolicy {
                    AboutLink(title: "プライバシーポリシー", destination: privacyPolicyURL)
                }
            }

            Section("データ") {
                NavigationLink("データ管理") {
                    DataManagementView()
                }
                .accessibilityIdentifier("data-management-link")
            }

            Section("通知") {
                LabeledContent("終了忘れ通知") {
                    Text(reminderCoordinator.notificationStatusText)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("workout-end-reminder-status")

                if reminderCoordinator.authorizationStatus == .denied {
                    Button("iPhoneの設定を開く") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        openURL(url)
                    }
                    .accessibilityHint("KASANEの通知設定を変更できます")
                    .accessibilityIdentifier("workout-end-reminder-open-settings")
                }
            }

            Section {
                Text("© 2026 yu1Ro5")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("KASANEについて")
        .task {
            await reminderCoordinator.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await reminderCoordinator.refreshAuthorizationStatus()
            }
        }
    }
}

private struct AboutLink: View {
    let title: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(title)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .environment(
        WorkoutEndReminderCoordinator(
            notificationCenter: DisabledWorkoutEndReminderNotificationCenter()
        )
    )
}

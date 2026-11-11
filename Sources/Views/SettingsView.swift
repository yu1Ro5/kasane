import SwiftUI

struct SettingsView: View {
    @Environment(WorkoutEndReminderCoordinator.self) private var reminderCoordinator
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section("種目") {
                NavigationLink {
                    ExerciseManagementView()
                } label: {
                    VStack(alignment: .leading) {
                        Text("種目管理")
                        Text("追加・編集・アーカイブ")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("exercise-management-link")
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
                if let url = AppLinks.feedback {
                    AboutLink(title: "ご意見・不具合を送る", destination: url)
                        .accessibilityIdentifier("feedback-form-link")
                }
                if let url = AppLinks.support { AboutLink(title: "サポート", destination: url) }
                if let url = AppLinks.privacyPolicy { AboutLink(title: "プライバシーポリシー", destination: url) }
            } header: {
                Text("サポート")
            } footer: {
                VStack(spacing: 4) {
                    Text("KASANE Version \(AppVersion.current)")
                    Text("© 2026 yu1Ro5")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("設定")
        .task { await reminderCoordinator.refreshAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reminderCoordinator.refreshAuthorizationStatus() } }
        }
    }
}

struct AboutLink: View {
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

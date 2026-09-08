import SwiftUI

/// アプリ情報と公開中のサポート情報への導線を表示する画面。
struct AboutView: View {
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

            Section {
                Text("© 2026 yu1Ro5")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("KASANEについて")
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
}

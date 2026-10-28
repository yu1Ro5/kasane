import SwiftUI

struct ReplayActivityPage: View {
    let stats: YearlyReplayStats

    private var presentation: ReplayActivityPresentation {
        ReplayActivityPresentation(stats: stats)
    }

    var body: some View {
        ReplayPageLayout {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVITY")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text("一年の積み重ね")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                }

                ReplayActivityVolumeCard(value: presentation.totalVolumeText)

                VStack(spacing: 0) {
                    ReplayActivityMetric(
                        title: "年間トレーニング時間",
                        value: presentation.totalDurationText,
                        systemImage: "clock"
                    )

                    Divider()
                        .padding(.vertical, 18)

                    ReplayActivityMetric(
                        title: "年間総セット数",
                        value: presentation.totalSetCountText,
                        systemImage: "square.stack.3d.up"
                    )
                }
                .padding(22)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                if let warningMessage = presentation.warningMessage {
                    Label(warningMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.orange.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .accessibilityIdentifier("replay-activity-long-workout-warning")
                }
            }
        }
        .accessibilityIdentifier("replay-activity-page")
    }
}

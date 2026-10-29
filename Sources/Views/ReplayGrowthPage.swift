import SwiftUI

struct ReplayGrowthPage: View {
    let stats: YearlyReplayStats

    private var presentation: ReplayGrowthPresentation {
        ReplayGrowthPresentation(stats: stats)
    }

    var body: some View {
        ReplayPageLayout {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GROWTH & PR")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text("一年の成長")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                }

                if let growth = presentation.growth {
                    ReplayBiggestGrowthCard(growth: growth)
                } else {
                    ReplayGrowthUnavailableCard()
                }

                ReplayPersonalRecordCard(countText: presentation.personalRecordCountText)
            }
        }
        .accessibilityIdentifier("replay-growth-page")
    }
}

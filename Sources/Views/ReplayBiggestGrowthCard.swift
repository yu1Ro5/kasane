import SwiftUI

struct ReplayBiggestGrowthCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var growthRateFontSize = 64

    let growth: ReplayGrowthContent

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.32),
                            Color.accentColor.opacity(0.08),
                            Color.secondary.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "arrow.up.right")
                .font(.system(size: 112, weight: .black))
                .foregroundStyle(Color.accentColor.opacity(0.10))
                .offset(x: 18, y: -14)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 18) {
                Label("今年最も成長した種目", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(growth.exerciseName)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(growth.growthRateText)
                    .font(.system(size: growthRateFontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                VStack(alignment: .leading, spacing: 5) {
                    Text("推定1RM")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(growth.estimatedOneRepMaxRangeText)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今年最も成長した種目")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let range = growth.estimatedOneRepMaxRangeText
            .replacing("kg", with: "キログラム")
            .replacing(" → ", with: "から")
        return "\(growth.exerciseName)、推定1RMの成長率\(growth.growthRateText)、推定1RMは\(range)"
    }
}

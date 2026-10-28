import SwiftUI

struct ReplayActivityVolumeCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var volumeFontSize = 54

    let value: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.30),
                            Color.accentColor.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 22)
                .frame(width: 128, height: 128)
                .offset(x: 36, y: -42)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Label("年間総Volume", systemImage: "scalemass")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: volumeFontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("年間総ボリューム")
        .accessibilityValue(value.replacing("kg", with: "キログラム"))
    }
}

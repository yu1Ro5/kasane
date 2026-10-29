import SwiftUI

struct ReplayGrowthUnavailableCard: View {
    var body: some View {
        ContentUnavailableView {
            Label(
                ReplayGrowthPresentation.unavailableMessage,
                systemImage: "chart.line.uptrend.xyaxis"
            )
        } description: {
            Text(ReplayGrowthPresentation.unavailableDescription)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 34)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color.secondary.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .accessibilityIdentifier("replay-growth-empty-state")
    }
}

import SwiftUI

struct ReplayMostTrainedResultCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var exerciseNameFontSize = 48

    let title: String
    let exerciseName: String
    let workoutCountText: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.26),
                            Color.secondary.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Capsule()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 170, height: 70)
                .rotationEffect(.degrees(-18))
                .offset(x: 42, y: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 22) {
                Text(exerciseName)
                    .font(.system(size: exerciseNameFontSize, weight: .black, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Label(workoutCountText, systemImage: "calendar.badge.checkmark")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(exerciseName)、\(workoutCountText)")
    }
}

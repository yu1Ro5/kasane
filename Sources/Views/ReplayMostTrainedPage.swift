import SwiftUI

struct ReplayMostTrainedPage: View {
    let stats: YearlyReplayStats

    private var presentation: ReplayMostTrainedPresentation {
        ReplayMostTrainedPresentation(stats: stats)
    }

    var body: some View {
        ReplayPageLayout {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MOST TRAINED")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text(presentation.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                }

                if let exerciseName = presentation.exerciseName,
                    let workoutCountText = presentation.workoutCountText
                {
                    ReplayMostTrainedResultCard(
                        title: presentation.title,
                        exerciseName: exerciseName,
                        workoutCountText: workoutCountText
                    )
                } else {
                    ContentUnavailableView {
                        Label(
                            ReplayMostTrainedPresentation.unavailableMessage,
                            systemImage: "figure.strengthtraining.traditional"
                        )
                    } description: {
                        Text(ReplayMostTrainedPresentation.unavailableDescription)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .accessibilityIdentifier("replay-most-trained-empty-state")
                }
            }
        }
        .accessibilityIdentifier("replay-most-trained-page")
    }
}

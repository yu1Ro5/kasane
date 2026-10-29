import SwiftUI

struct ReplayClosingPage: View {
    @ScaledMetric(relativeTo: .largeTitle) private var workoutCountFontSize = 72

    let presentation: ReplayClosingPresentation
    let replayAction: () -> Void
    let closeAction: () -> Void

    var body: some View {
        ReplayPageLayout {
            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Text("KASANE REPLAY")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)

                    Text("\(presentation.year)")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .monospacedDigit()
                        .accessibilityLabel("\(presentation.year)年")

                    Text(presentation.message)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                workoutCount

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        replayButton
                        closeButton
                    }

                    VStack(spacing: 10) {
                        replayButton
                        closeButton
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 20)
        }
        .accessibilityIdentifier("replay-closing-page")
    }

    private var workoutCount: some View {
        VStack(spacing: 8) {
            Text("\(presentation.workoutCount)")
                .font(.system(size: workoutCountFontSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text("年間ワークアウト")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.24),
                    Color.accentColor.opacity(0.07),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("年間ワークアウト")
        .accessibilityValue("\(presentation.workoutCount)回")
    }

    private var replayButton: some View {
        Button(action: replayAction) {
            Label("もう一度見る", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint("選択中の年のIntroへ戻る")
        .accessibilityIdentifier("replay-restart-button")
    }

    private var closeButton: some View {
        Button(action: closeAction) {
            Label("閉じる", systemImage: "xmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint("Replayを閉じて概要へ戻る")
        .accessibilityIdentifier("replay-closing-close-button")
    }
}

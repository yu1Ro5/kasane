import SwiftUI

/// 保存済みワークアウトの集計結果とホームへ戻る導線を表示する完了画面。
struct WorkoutCompletedView: View {
    /// 保存に成功したワークアウトの集計結果。
    let summary: WorkoutCompletionSummary
    /// 「完了」を選択したときに実行する処理。
    let onReturnHome: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 32)

                Text("WORKOUT COMPLETE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                    .accessibilityHidden(true)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 18)
                    .accessibilityHidden(true)
                    .completionAppearance(hasAppeared, reduceMotion: reduceMotion)

                Text("今日も積み重ねました")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .accessibilitySortPriority(4)
                    .completionAppearance(hasAppeared, delay: 0.12, reduceMotion: reduceMotion)

                durationSummary
                    .padding(.top, 44)
                    .accessibilitySortPriority(3)
                    .completionAppearance(hasAppeared, delay: 0.24, reduceMotion: reduceMotion)

                statistics
                    .padding(.top, 36)
                    .accessibilitySortPriority(2)
                    .completionAppearance(hasAppeared, delay: 0.32, reduceMotion: reduceMotion)

                Spacer(minLength: 32)
            }
            .frame(maxWidth: .infinity, minHeight: 480)
            .padding(.horizontal, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onReturnHome) {
                Text("完了")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .accessibilitySortPriority(1)
        }
        .navigationBarBackButtonHidden()
        .sensoryFeedback(.success, trigger: hasAppeared)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    private var durationSummary: some View {
        VStack(spacing: 6) {
            Text(durationText)
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .multilineTextAlignment(.center)
            Text("トレーニング時間")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("トレーニング時間")
        .accessibilityValue(durationText)
    }

    @ViewBuilder
    private var statistics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                statisticCard(value: summary.exerciseCount, label: "種目")
                statisticCard(value: summary.setCount, label: "セット")
            }
            VStack(spacing: 12) {
                statisticCard(value: summary.exerciseCount, label: "種目")
                statisticCard(value: summary.setCount, label: "セット")
            }
        }
    }

    private var durationText: String {
        let totalMinutes = Int(summary.duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

    private func statisticCard(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.title.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
    }
}

private extension View {
    /// 完了画面の各領域を控えめに表示する。
    func completionAppearance(
        _ isVisible: Bool,
        delay: TimeInterval = 0,
        reduceMotion: Bool
    ) -> some View {
        opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion || isVisible ? 1 : 0.96)
            .animation(.easeOut(duration: 0.28).delay(delay), value: isVisible)
    }
}

import SwiftUI

/// Presents one achievement at a time before continuing to workout completion.
struct PersonalRecordSequenceView: View {
    let achievements: [PersonalRecordAchievement]
    let summary: WorkoutCompletionSummary
    let onReturnHome: () -> Void

    @State private var currentIndex = 0

    var body: some View {
        if currentIndex < achievements.count {
            PersonalRecordView(
                achievement: achievements[currentIndex],
                actionTitle: currentIndex == achievements.count - 1 ? "完了画面へ" : "次へ"
            ) {
                currentIndex += 1
            }
            .id(achievements[currentIndex].id)
        } else {
            WorkoutCompletedView(summary: summary, onReturnHome: onReturnHome)
        }
    }
}

/// A full-screen celebration for a maximum-weight personal record.
struct PersonalRecordView: View {
    let achievement: PersonalRecordAchievement
    let actionTitle: String
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var recordFontSize = 64
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 28)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 58, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.yellow, Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.22), radius: 18)
                        .accessibilityHidden(true)
                        .recordAppearance(hasAppeared, reduceMotion: reduceMotion)

                    Text("自己ベスト更新")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)

                    Text("NEW RECORD")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(Color.accentColor)
                        .tracking(1.5)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        .padding(.top, 8)
                        .recordAppearance(hasAppeared, delay: 0.08, reduceMotion: reduceMotion)

                    Text(achievement.exerciseName)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)

                    Text(WorkoutSetDisplayFormatter.displayWeight(achievement.newBest))
                        .font(.system(size: recordFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .padding(.top, 12)
                        .recordAppearance(hasAppeared, delay: 0.16, reduceMotion: reduceMotion)

                    Text("前回より +\(WorkoutSetDisplayFormatter.displayWeight(achievement.improvement))")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                        .padding(.top, 12)

                    comparison
                        .padding(.top, 34)

                    Text("積み重ねた結果、記録を更新しました")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 30)

                    Spacer(minLength: 32)
                }
                .frame(maxWidth: .infinity, minHeight: 570)
                .padding(.horizontal, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text(actionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("personal-record-continue-button")
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .sensoryFeedback(.success, trigger: hasAppeared)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.16), Color.clear, Color.accentColor.opacity(0.07)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var comparison: some View {
        HStack(spacing: 12) {
            comparisonValue("Previous", weight: achievement.previousBest, emphasized: false)
            Image(systemName: "arrow.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            comparisonValue("New Record", weight: achievement.newBest, emphasized: true)
        }
    }

    private func comparisonValue(_ label: String, weight: Double, emphasized: Bool) -> some View {
        VStack(spacing: 7) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(emphasized ? Color.accentColor : Color.secondary)
            Text(WorkoutSetDisplayFormatter.displayWeight(weight))
                .font(.title3.weight(.bold))
                .foregroundStyle(emphasized ? Color.accentColor : Color.secondary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    func recordAppearance(
        _ isVisible: Bool,
        delay: TimeInterval = 0,
        reduceMotion: Bool
    ) -> some View {
        opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion || isVisible ? 1 : 0.88)
            .animation(.easeOut(duration: 0.36).delay(delay), value: isVisible)
    }
}

#Preview {
    NavigationStack {
        PersonalRecordView(
            achievement: PersonalRecordAchievement(
                exerciseID: UUID(),
                exerciseName: "レッグプレス",
                previousBest: 63,
                newBest: 72
            ),
            actionTitle: "完了画面へ",
            onContinue: {}
        )
    }
}

import SwiftUI

struct OverviewReplayBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: OverviewReplayBannerPresentation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    bannerIcon
                    bannerText
                    Spacer(minLength: 8)
                    chevron
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        bannerIcon
                        Spacer(minLength: 8)
                        chevron
                    }
                    bannerText
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.16),
                                Color.accentColor.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue("一年の積み重ねを振り返る")
        .accessibilityHint("ダブルタップしてReplayを開く")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("overview-replay-banner")
    }

    private var bannerIcon: some View {
        Image(systemName: "play.circle.fill")
            .font(dynamicTypeSize.isAccessibilitySize ? .title : .title2)
            .foregroundStyle(Color.accentColor)
            .frame(minWidth: 44, minHeight: 44)
            .background(Color.accentColor.opacity(0.10), in: Circle())
            .accessibilityHidden(true)
    }

    private var bannerText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presentation.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("一年の積み重ねを振り返る")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

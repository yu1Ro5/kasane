import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

struct AdBannerView: View {
    let mode: AdConfiguration
    let consent: AdConsentManager
    @State private var width: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if mode == .googleTest && consent.needsPrivacyOptions {
                Button {
                    Task { await consent.showPrivacyOptions() }
                } label: {
                    Text("広告のプライバシー設定")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(consent.isBusy)
                if consent.optionsFailed {
                    Text("設定を開けませんでした。もう一度お試しください。")
                        .font(.footnote)
                }
            }
            if mode == .stub {
                VStack(alignment: .leading) {
                    adLabel
                    Text("テストバナー")
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(.quaternary)
                }
            } else if mode == .googleTest && consent.mayLoadBanner && width > 0 {
                AdaptiveBanner(width: width)
                    .id(width)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) {
            floor($0.size.width)
        } action: {
            width = $0
        }
    }
}

private var adLabel: some View {
    Text("広告")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("overview-ad-label")
}

private struct AdaptiveBanner: View {
    let width: CGFloat
    @State private var height: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if height > 0 { adLabel }
            GoogleBanner(width: width, height: $height)
                .frame(width: width, height: height)
                .clipped()
                .accessibilityHidden(height == 0)
                .allowsHitTesting(height > 0)
        }
    }
}

private struct GoogleBanner: UIViewRepresentable {
    let width: CGFloat
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: inlineAdaptiveBanner(width: width, maxHeight: 60))
        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"
        banner.delegate = context.coordinator
        if ConsentInformation.shared.canRequestAds {
            banner.load(Request())
        }
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    @MainActor
    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var height: CGFloat

        init(height: Binding<CGFloat>) { _height = height }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            height = max(0, bannerView.intrinsicContentSize.height)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            height = 0
        }
    }
}

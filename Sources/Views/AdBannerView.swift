import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

struct AdBannerView: View {
    let mode: AdConfiguration
    let consent: AdConsentManager
    /// Only populated for TestFlight. Never show this in an App Store release.
    let testFlightDiagnostic: String?
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
            } else if mode == .googleTest {
                if consent.mayLoadBanner && width > 0 {
                    AdaptiveBanner(
                        width: width, testFlightDiagnostic: testFlightDiagnostic,
                        consentLines: consent.diagnosticLines
                    )
                    .id(width)
                } else if let testFlightDiagnostic {
                    AdDebugPanel(lines: [testFlightDiagnostic] + consent.diagnosticLines)
                }
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

@MainActor
private var adLabel: some View {
    Text("広告")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("overview-ad-label")
}

/// This panel is shown only when the TestFlight banner is unavailable.
struct AdDebugPanel: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AdMob診断（TestFlight限定）", systemImage: "ladybug")
                .font(.subheadline.weight(.semibold))
            ForEach(Array(lines.enumerated()), id: \.offset) { entry in
                Text(entry.element)
                    .font(.caption.monospaced())
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Button {
                UIPasteboard.general.string = lines.joined(separator: "\n")
            } label: {
                Label("診断情報をコピー", systemImage: "doc.on.doc")
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .padding(14)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("admob-testflight-debug-panel")
    }
}

private struct AdaptiveBanner: View {
    let width: CGFloat
    let testFlightDiagnostic: String?
    let consentLines: [String]
    @State private var height: CGFloat = 0
    @State private var bannerStatus = "Banner: requesting Google demo ad"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if height > 0 { adLabel }
            GoogleBanner(width: width, height: $height, bannerStatus: $bannerStatus)
                .frame(width: width, height: height)
                .clipped()
                .accessibilityHidden(height == 0)
                .allowsHitTesting(height > 0)
            if height == 0, let testFlightDiagnostic {
                AdDebugPanel(lines: [testFlightDiagnostic] + consentLines + [bannerStatus])
            }
        }
    }
}

private struct GoogleBanner: UIViewRepresentable {
    let width: CGFloat
    @Binding var height: CGFloat
    @Binding var bannerStatus: String

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

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, bannerStatus: $bannerStatus)
    }

    @MainActor
    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var height: CGFloat
        @Binding var bannerStatus: String

        init(height: Binding<CGFloat>, bannerStatus: Binding<String>) {
            _height = height
            _bannerStatus = bannerStatus
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            bannerStatus = "Banner: loaded"
            height = max(0, bannerView.intrinsicContentSize.height)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            let nsError = error as NSError
            bannerStatus = "Banner error: \(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
            height = 0
        }
    }
}

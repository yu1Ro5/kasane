import GoogleMobileAds
@preconcurrency import UserMessagingPlatform

@MainActor
struct GoogleAdConsentClient: AdConsentClient {
    var needsPrivacyOptions: Bool { ConsentInformation.shared.privacyOptionsRequirementStatus == .required }
    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

    func update() async throws {
        try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
    }

    func presentRequiredForm() async throws {
        guard ConsentInformation.shared.consentStatus == .required else { return }
        let form = try await ConsentForm.load()
        try Task.checkCancellation()
        try await form.present(from: nil)
    }

    func presentOptions() async throws { try await ConsentForm.presentPrivacyOptionsForm(from: nil) }

    func startAds() async {
        let configuration = MobileAds.shared.requestConfiguration
        configuration.publisherPrivacyPersonalizationState = .disabled
        configuration.setPublisherFirstPartyIDEnabled(false)
        configuration.maxAdContentRating = .general
        await withCheckedContinuation { continuation in
            MobileAds.shared.start { _ in continuation.resume() }
        }
    }
}

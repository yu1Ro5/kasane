import Observation

@MainActor
protocol AdConsentClient {
    var needsPrivacyOptions: Bool { get }
    var canRequestAds: Bool { get }
    func update() async throws
    func presentRequiredForm() async throws
    func presentOptions() async throws
    func startAds() async
}

@MainActor
@Observable
final class AdConsentManager {
    private(set) var mayLoadBanner = false
    private(set) var needsPrivacyOptions = false
    private(set) var isBusy = false
    private(set) var optionsFailed = false
    private var didPrepare = false
    private var startedSDK = false

    private let client: any AdConsentClient

    init(client: any AdConsentClient) {
        self.client = client
    }

    func prepare() async {
        guard !didPrepare, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await client.update()
            needsPrivacyOptions = client.needsPrivacyOptions
            guard !Task.isCancelled else { return }
            try await client.presentRequiredForm()
            try Task.checkCancellation()
            didPrepare = true
            await applyConsent()
        } catch {
            // Require a successful update and form flow in this session, even with cached consent.
            mayLoadBanner = false
        }
    }

    func showPrivacyOptions() async {
        guard needsPrivacyOptions, !isBusy else { return }
        isBusy = true
        mayLoadBanner = false
        optionsFailed = false
        defer { isBusy = false }
        do {
            try await client.presentOptions()
            await applyConsent()
        } catch {
            optionsFailed = true
        }
    }

    private func applyConsent() async {
        needsPrivacyOptions = client.needsPrivacyOptions
        guard client.canRequestAds else { return }
        if !startedSDK {
            await client.startAds()
            startedSDK = true
        }
        mayLoadBanner = client.canRequestAds
    }
}

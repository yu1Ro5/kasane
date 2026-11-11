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
    private(set) var diagnosticStage = "UMP: not started"
    private(set) var diagnosticError: String?
    private(set) var diagnosticCanRequestAds: Bool?
    private(set) var diagnosticSDKStarted = false

    var diagnosticLines: [String] {
        [
            diagnosticStage,
            "UMP canRequestAds: \(diagnosticCanRequestAds.map(String.init) ?? "unknown")",
            "GMA initialized: \(diagnosticSDKStarted)",
        ] + (diagnosticError.map { [$0] } ?? [])
    }
    private var didPrepare = false
    private var startedSDK = false

    private let client: any AdConsentClient

    init(client: any AdConsentClient) {
        self.client = client
    }

    func prepare() async {
        // Wait for a previous preparation to finish, so a cancelled attempt can be retried.
        while isBusy {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
        }
        guard !didPrepare, !Task.isCancelled else { return }
        isBusy = true
        diagnosticStage = "UMP: updating consent information"
        diagnosticError = nil
        defer { isBusy = false }
        do {
            try await client.update()
            diagnosticStage = "UMP: update succeeded; checking consent form"
            diagnosticCanRequestAds = client.canRequestAds
            needsPrivacyOptions = client.needsPrivacyOptions
            guard !Task.isCancelled else {
                diagnosticStage = "UMP: task cancelled"
                return
            }
            try await client.presentRequiredForm()
            try Task.checkCancellation()
            didPrepare = true
            await applyConsent()
        } catch {
            // Require a successful update and form flow in this session, even with cached consent.
            mayLoadBanner = false
            diagnosticStage = "UMP: consent preparation failed"
            diagnosticCanRequestAds = client.canRequestAds
            let nsError = error as NSError
            diagnosticError = "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
        }
    }

    func showPrivacyOptions() async {
        guard needsPrivacyOptions, !isBusy else { return }
        isBusy = true
        mayLoadBanner = false
        optionsFailed = false
        diagnosticStage = "UMP: presenting privacy options"
        defer { isBusy = false }
        do {
            try await client.presentOptions()
            await applyConsent()
        } catch {
            optionsFailed = true
            diagnosticStage = "UMP: privacy options failed"
            let nsError = error as NSError
            diagnosticError = "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
        }
    }

    private func applyConsent() async {
        needsPrivacyOptions = client.needsPrivacyOptions
        diagnosticCanRequestAds = client.canRequestAds
        guard client.canRequestAds else {
            diagnosticStage = "UMP: ad requests blocked by consent state"
            return
        }
        if !startedSDK {
            diagnosticStage = "GMA: initializing"
            await client.startAds()
            startedSDK = true
            diagnosticSDKStarted = true
        }
        mayLoadBanner = client.canRequestAds
        diagnosticCanRequestAds = mayLoadBanner
        diagnosticStage = mayLoadBanner ? "GMA: ready to request banner" : "UMP: consent no longer permits ads"
    }
}

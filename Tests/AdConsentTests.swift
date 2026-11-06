import XCTest

@testable import KASANE

@MainActor
final class AdConsentTests: XCTestCase {
    func testUpdateFailureBlocksCachedConsent() async {
        let client = Client()
        client.updateFails = true
        let manager = AdConsentManager(client: client)
        await manager.prepare()
        XCTAssertEqual(client.calls, ["update"])
        XCTAssertFalse(manager.mayLoadBanner)
    }

    func testCancelledPreparationRetriesAfterReturningWhileUpdateIsInFlight() async {
        let client = Client()
        client.pauseNextUpdate = true
        let updatePaused = expectation(description: "First consent update is pending")
        client.updatePausedExpectation = updatePaused
        let manager = AdConsentManager(client: client)

        let first = Task { await manager.prepare() }
        await fulfillment(of: [updatePaused], timeout: 2)
        XCTAssertTrue(manager.isBusy)

        // The second visit to Overview happens while the first update is still busy.
        let finishFirst = Task {
            first.cancel()
            client.resumePausedUpdate()
        }
        await manager.prepare()
        await finishFirst.value
        await first.value

        XCTAssertEqual(client.calls, ["update", "update", "required", "start"])
        XCTAssertTrue(manager.mayLoadBanner)
        XCTAssertFalse(manager.isBusy)
    }

    func testPermissionIsCheckedAfterBothForms() async {
        let client = Client()
        client.canRequestAds = false
        let manager = AdConsentManager(client: client)
        await manager.prepare()
        XCTAssertEqual(client.calls, ["update", "required"])
        XCTAssertFalse(manager.mayLoadBanner)
        XCTAssertTrue(manager.needsPrivacyOptions)

        client.canRequestAds = true
        await manager.showPrivacyOptions()
        await manager.prepare()
        XCTAssertTrue(manager.mayLoadBanner)
        XCTAssertEqual(client.calls, ["update", "required", "options", "start"])

        client.canRequestAds = false
        await manager.showPrivacyOptions()
        XCTAssertFalse(manager.mayLoadBanner)
    }

    func testFormFailureBlocksAdsAndOptionsFailureRemovesBanner() async {
        let client = Client()
        client.formFails = true
        let manager = AdConsentManager(client: client)
        await manager.prepare()
        XCTAssertFalse(manager.mayLoadBanner)
        XCTAssertEqual(client.calls, ["update", "required"])
        client.formFails = false
        await manager.prepare()
        XCTAssertTrue(manager.mayLoadBanner)
        client.formFails = true
        await manager.showPrivacyOptions()
        XCTAssertFalse(manager.mayLoadBanner)
        XCTAssertTrue(manager.optionsFailed)
    }

    private final class Client: AdConsentClient {
        var needsPrivacyOptions = true
        var canRequestAds = true
        var calls: [String] = []
        var updateFails = false
        var formFails = false
        var pauseNextUpdate = false
        var updatePausedExpectation: XCTestExpectation?
        private var pausedUpdateContinuation: CheckedContinuation<Void, Never>?

        func update() async throws {
            calls.append("update")
            if pauseNextUpdate {
                pauseNextUpdate = false
                await withCheckedContinuation { continuation in
                    pausedUpdateContinuation = continuation
                    updatePausedExpectation?.fulfill()
                }
            }
            if updateFails { throw URLError(.notConnectedToInternet) }
        }

        func resumePausedUpdate() {
            pausedUpdateContinuation?.resume()
            pausedUpdateContinuation = nil
        }

        func presentRequiredForm() async throws {
            calls.append("required")
            if formFails { throw URLError(.notConnectedToInternet) }
        }
        func presentOptions() async throws {
            calls.append("options")
            if formFails { throw URLError(.notConnectedToInternet) }
        }
        func startAds() async { calls.append("start") }
    }
}

import Foundation
import StoreKit

struct AdConfigurationResolution {
    let mode: AdConfiguration
    /// Non-nil only for a verified (or plausibly identified) TestFlight install.
    /// Production App Store installs must never render diagnostic UI.
    let testFlightDiagnostic: String?
}

enum AdConfiguration: Equatable {
    case off, stub, googleTest

    static func current() async -> Self {
        await currentWithDiagnostics().mode
    }

    static func currentWithDiagnostics() async -> AdConfigurationResolution {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
            return AdConfigurationResolution(mode: resolve(arguments: arguments), testFlightDiagnostic: nil)
        #else
            if arguments.contains("--ui-testing") {
                return AdConfigurationResolution(
                    mode: resolve(arguments: arguments, isDebug: false, isTestFlight: false),
                    testFlightDiagnostic: nil
                )
            }
            do {
                switch try await AppTransaction.shared {
                case .verified(let transaction):
                    return resolveDistribution(
                        isSandbox: transaction.environment == .sandbox,
                        isVerified: true
                    )
                case .unverified(let transaction, let error):
                    return resolveDistribution(
                        isSandbox: transaction.environment == .sandbox,
                        isVerified: false,
                        reason: "StoreKit verification failed: \(error.localizedDescription)"
                    )
                }
            } catch {
                // StoreKit 2 may fail before returning a transaction. This receipt
                // hint shows diagnostics only; it never authorizes ad requests.
                let sandboxReceipt = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
                return resolveDistribution(
                    isSandbox: sandboxReceipt,
                    isVerified: false,
                    reason: "StoreKit lookup failed: \(error.localizedDescription)"
                )
            }
        #endif
    }

    static func resolveDistribution(
        isSandbox: Bool,
        isVerified: Bool,
        reason: String? = nil
    ) -> AdConfigurationResolution {
        guard isSandbox else {
            return AdConfigurationResolution(mode: .off, testFlightDiagnostic: nil)
        }
        if isVerified {
            return AdConfigurationResolution(
                mode: .googleTest, testFlightDiagnostic: "StoreKit: TestFlight / sandbox (verified)"
            )
        }
        return AdConfigurationResolution(
            mode: .off,
            testFlightDiagnostic: reason ?? "StoreKit: sandbox detected, transaction unverified"
        )
    }

    static func resolve(arguments: [String]) -> Self {
        resolve(arguments: arguments, isDebug: true, isTestFlight: false)
    }

    static func resolve(arguments: [String], isDebug: Bool, isTestFlight: Bool) -> Self {
        if arguments.contains("--ui-testing") {
            return arguments.contains("--stub-overview-banner") ? .stub : .off
        }
        if isDebug {
            return arguments.contains("--enable-admob-test-banner") ? .googleTest : .off
        }
        return isTestFlight ? .googleTest : .off
    }
}

import Foundation
import StoreKit

enum AdConfiguration: Equatable {
    case off, stub, googleTest

    static func current() async -> Self {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
            return resolve(arguments: arguments)
        #else
            // TestFlight is a Release build. Determine distribution from the signed
            // App Store transaction, never from the compilation configuration.
            // Any failed or unverified lookup must leave advertising disabled.
            if arguments.contains("--ui-testing") {
                return resolve(arguments: arguments, isDebug: false, isTestFlight: false)
            }
            do {
                guard case .verified(let transaction) = try await AppTransaction.shared else {
                    return .off
                }
                return resolve(
                    arguments: arguments,
                    isDebug: false,
                    isTestFlight: transaction.environment == .sandbox
                )
            } catch {
                return .off
            }
        #endif
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

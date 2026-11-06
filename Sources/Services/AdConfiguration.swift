import Foundation

enum AdConfiguration: Equatable {
    case off, stub, googleTest

    static var current: Self {
        #if DEBUG
            resolve(arguments: ProcessInfo.processInfo.arguments)
        #else
            .off
        #endif
    }

    static func resolve(arguments: [String]) -> Self {
        if arguments.contains("--ui-testing") {
            return arguments.contains("--stub-overview-banner") ? .stub : .off
        }
        return arguments.contains("--enable-admob-test-banner") ? .googleTest : .off
    }
}

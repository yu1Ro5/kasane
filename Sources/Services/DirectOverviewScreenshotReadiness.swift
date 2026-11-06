#if DEBUG
    import Foundation
    import OSLog

    /// Signals fixture content readiness; the capture script separately checks pixel stability.
    enum DirectOverviewScreenshotReadiness {
        static func markReady() {
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("--ui-testing"),
                arguments.contains("--direct-overview-screenshot"),
                let token = ProcessInfo.processInfo.environment["KASANE_SCREENSHOT_TOKEN"],
                !token.isEmpty
            else { return }

            do {
                try token.write(
                    to: URL.documentsDirectory.appending(path: ".kasane-overview-ready"),
                    atomically: true, encoding: .utf8
                )
            } catch {
                Logger(subsystem: "com.yu1Ro5.kasane", category: "DirectScreenshot")
                    .error("Cannot signal overview readiness: \(error.localizedDescription)")
            }
        }
    }
#endif

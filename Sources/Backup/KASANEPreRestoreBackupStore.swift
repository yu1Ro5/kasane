import Foundation

protocol KASANEPreRestoreBackupStoring: Sendable {
    func save(_ data: Data) async throws
}

enum KASANEPreRestoreBackupStoreError: Error, Equatable {
    case directoryUnavailable
    case writeFailed
}

actor KASANEPreRestoreBackupStore: KASANEPreRestoreBackupStoring {
    private let applicationSupportURLProvider: @Sendable () -> URL?

    init(
        applicationSupportURLProvider: @escaping @Sendable () -> URL? = {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        }
    ) {
        self.applicationSupportURLProvider = applicationSupportURLProvider
    }

    func save(_ data: Data) async throws {
        guard let applicationSupportURL = applicationSupportURLProvider() else {
            throw KASANEPreRestoreBackupStoreError.directoryUnavailable
        }
        let directory =
            applicationSupportURL
            .appending(path: "KASANE", directoryHint: .isDirectory)
            .appending(path: "RestoreSafety", directoryHint: .isDirectory)
        let destination = directory.appending(
            path: "pre-restore-latest.json", directoryHint: .notDirectory)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: destination, options: .atomic)
        } catch {
            throw KASANEPreRestoreBackupStoreError.writeFailed
        }
    }
}

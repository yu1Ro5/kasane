import Foundation

protocol KASANECloudBackupStoring: Sendable {
    func save(_ data: Data) async throws
    func loadLatest() async throws -> Data
    func latestBackupExists() async throws -> Bool
}

enum KASANEICloudBackupStoreError: Error, Equatable {
    case unavailable
    case containerUnavailable
    case backupNotFound
    case downloadFailed
    case downloadTimedOut
    case readFailed
    case writeFailed
}

actor KASANEICloudBackupStore: KASANECloudBackupStoring {
    static let containerIdentifier = "iCloud.com.yu1Ro5.kasane"

    private let containerURLProvider: @Sendable () -> URL?
    private let isICloudAvailable: @Sendable () -> Bool
    private let downloadTimeout: Duration
    private let pollInterval: Duration
    private let requiresUbiquitousDownload: Bool

    init(
        containerURLProvider: @escaping @Sendable () -> URL? = {
            FileManager.default.url(
                forUbiquityContainerIdentifier: KASANEICloudBackupStore.containerIdentifier
            )
        },
        isICloudAvailable: @escaping @Sendable () -> Bool = {
            FileManager.default.ubiquityIdentityToken != nil
        },
        downloadTimeout: Duration = .seconds(30),
        pollInterval: Duration = .milliseconds(250),
        requiresUbiquitousDownload: Bool = true
    ) {
        self.containerURLProvider = containerURLProvider
        self.isICloudAvailable = isICloudAvailable
        self.downloadTimeout = downloadTimeout
        self.pollInterval = pollInterval
        self.requiresUbiquitousDownload = requiresUbiquitousDownload
    }

    func save(_ data: Data) async throws {
        let url = try latestURL()
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw KASANEICloudBackupStoreError.writeFailed
        }

        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        guard coordinationError == nil, writeError == nil else {
            throw KASANEICloudBackupStoreError.writeFailed
        }
    }

    func loadLatest() async throws -> Data {
        let url = try latestURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw KASANEICloudBackupStoreError.backupNotFound
        }
        if requiresUbiquitousDownload {
            try await ensureDownloaded(url)
        }

        var coordinationError: NSError?
        var readResult: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
            coordinatedURL in
            readResult = Result { try Data(contentsOf: coordinatedURL) }
        }
        guard coordinationError == nil, let readResult else {
            throw KASANEICloudBackupStoreError.readFailed
        }
        do {
            return try readResult.get()
        } catch {
            throw KASANEICloudBackupStoreError.readFailed
        }
    }

    func latestBackupExists() async throws -> Bool {
        FileManager.default.fileExists(atPath: try latestURL().path)
    }

    private func latestURL() throws -> URL {
        guard isICloudAvailable() else {
            throw KASANEICloudBackupStoreError.unavailable
        }
        guard let containerURL = containerURLProvider() else {
            throw KASANEICloudBackupStoreError.containerUnavailable
        }
        return
            containerURL
            .appending(path: "Documents", directoryHint: .isDirectory)
            .appending(path: "KASANE", directoryHint: .isDirectory)
            .appending(path: "Backups", directoryHint: .isDirectory)
            .appending(path: "latest.json", directoryHint: .notDirectory)
    }

    private func ensureDownloaded(_ url: URL) async throws {
        do {
            let values = try url.resourceValues(forKeys: [
                .ubiquitousItemIsDownloadedKey,
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemDownloadingErrorKey,
            ])
            if values.ubiquitousItemIsDownloaded == true
                || values.ubiquitousItemDownloadingStatus == .current
            {
                return
            }
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            throw KASANEICloudBackupStoreError.downloadFailed
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: downloadTimeout)
        while clock.now < deadline {
            do {
                let values = try url.resourceValues(forKeys: [
                    .ubiquitousItemIsDownloadedKey,
                    .ubiquitousItemDownloadingStatusKey,
                    .ubiquitousItemDownloadingErrorKey,
                ])
                if values.ubiquitousItemIsDownloaded == true
                    || values.ubiquitousItemDownloadingStatus == .current
                {
                    return
                }
                if values.ubiquitousItemDownloadingError != nil {
                    throw KASANEICloudBackupStoreError.downloadFailed
                }
            } catch let error as KASANEICloudBackupStoreError {
                throw error
            } catch {
                throw KASANEICloudBackupStoreError.downloadFailed
            }
            try await clock.sleep(for: pollInterval)
        }
        throw KASANEICloudBackupStoreError.downloadTimedOut
    }
}

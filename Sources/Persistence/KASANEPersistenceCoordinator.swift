import Foundation
import SwiftData

@MainActor
struct KASANEPersistenceCoordinator {
    static let currentVersion = 1

    enum PersistenceError: Error {
        case downgradeDetected(storedVersion: Int, currentVersion: Int)
        case migrationAndRestoreFailed(migration: any Error, restore: any Error)
    }

    typealias ContainerFactory = (Schema, ModelConfiguration) throws -> ModelContainer

    private let configuration: ModelConfiguration
    private let markerStore: SchemaVersionMarkerStore
    private let snapshotStore: any MigrationSnapshotStoring
    private let fileManager: FileManager
    private let makeContainer: ContainerFactory

    init(
        configuration: ModelConfiguration? = nil,
        markerStore: SchemaVersionMarkerStore = SchemaVersionMarkerStore(),
        snapshotStore: (any MigrationSnapshotStoring)? = nil,
        fileManager: FileManager = .default,
        makeContainer: ContainerFactory? = nil
    ) {
        let schema = Schema(versionedSchema: CurrentKASANESchema.self)
        let resolvedConfiguration = configuration ?? ModelConfiguration(schema: schema)
        self.configuration = resolvedConfiguration
        self.markerStore = markerStore
        self.snapshotStore =
            snapshotStore
            ?? MigrationSnapshotStore(
                rootURL: resolvedConfiguration.url.deletingLastPathComponent()
                    .appendingPathComponent("MigrationSnapshots", isDirectory: true),
                fileManager: fileManager
            )
        self.fileManager = fileManager
        self.makeContainer =
            makeContainer ?? { schema, configuration in
                try ModelContainer(
                    for: schema,
                    migrationPlan: KASANEMigrationPlan.self,
                    configurations: configuration
                )
            }
    }

    func make() throws -> ModelContainer {
        let marker = markerStore.load()
        if let marker, marker > Self.currentVersion {
            throw PersistenceError.downgradeDetected(
                storedVersion: marker,
                currentVersion: Self.currentVersion
            )
        }

        let storeExists = fileManager.fileExists(atPath: configuration.url.path)
        let needsMigrationProtection = storeExists && marker != Self.currentVersion
        var hasRecoverySnapshot = false

        if let pendingSnapshot = try snapshotStore.pendingSnapshotMetadata() {
            if pendingSnapshot.targetVersion > Self.currentVersion {
                throw PersistenceError.downgradeDetected(
                    storedVersion: pendingSnapshot.targetVersion,
                    currentVersion: Self.currentVersion
                )
            }
            if marker == Self.currentVersion {
                try snapshotStore.deletePendingSnapshot()
            } else {
                try snapshotStore.restorePendingSnapshot(storeURL: configuration.url)
                hasRecoverySnapshot = true
            }
        } else if needsMigrationProtection {
            try snapshotStore.createPendingSnapshot(
                storeURL: configuration.url,
                sourceVersion: marker,
                targetVersion: Self.currentVersion
            )
            hasRecoverySnapshot = true
        }

        let container: ModelContainer
        do {
            container = try makeContainer(
                Schema(versionedSchema: CurrentKASANESchema.self),
                configuration
            )
        } catch let migrationError {
            guard hasRecoverySnapshot else { throw migrationError }
            do {
                try snapshotStore.restorePendingSnapshot(storeURL: configuration.url)
            } catch let restoreError {
                throw PersistenceError.migrationAndRestoreFailed(
                    migration: migrationError,
                    restore: restoreError
                )
            }
            throw migrationError
        }
        markerStore.save(Self.currentVersion)
        if hasRecoverySnapshot {
            try snapshotStore.deletePendingSnapshot()
        }
        return container
    }
}

extension KASANEPersistenceCoordinator.PersistenceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .downgradeDetected:
            "このデータは新しいバージョンのKASANEで作成されています。アプリを更新してください。"
        case .migrationAndRestoreFailed:
            "データの更新と復元の両方に失敗しました。データを削除せず、サポートへお問い合わせください。"
        }
    }
}

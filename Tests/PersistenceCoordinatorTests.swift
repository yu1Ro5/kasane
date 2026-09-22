import Foundation
import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class PersistenceCoordinatorTests: XCTestCase {
    func testLocalConfigurationDisablesCloudKitWithoutChangingDefaultStoreURL() {
        let schema = Schema(versionedSchema: CurrentKASANESchema.self)
        let previousConfiguration = ModelConfiguration(schema: schema)

        let configuration = KASANEPersistenceCoordinator.localConfiguration(schema: schema)

        XCTAssertEqual(configuration.url, previousConfiguration.url)
    }

    func testExistingOnDiskStoreReopensWithLocalConfigurationWithoutLosingData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("existing.store")
        let schema = Schema(versionedSchema: CurrentKASANESchema.self)

        let sessionID = try XCTUnwrap(UUID(uuidString: "10000000-0000-4000-8000-000000000175"))
        let exerciseID = try XCTUnwrap(UUID(uuidString: "20000000-0000-4000-8000-000000000175"))
        let entryID = try XCTUnwrap(UUID(uuidString: "30000000-0000-4000-8000-000000000175"))
        let setID = try XCTUnwrap(UUID(uuidString: "40000000-0000-4000-8000-000000000175"))
        let startedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let endedAt = Date(timeIntervalSince1970: 1_750_003_600)

        do {
            let existingContainer = try ModelContainer(
                for: schema,
                migrationPlan: KASANEMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
            )
            let context = existingContainer.mainContext
            let session = WorkoutSession(
                id: sessionID,
                startedAt: startedAt,
                endedAt: endedAt,
                note: "existing workout"
            )
            let exercise = Exercise(
                id: exerciseID,
                name: "Existing Bench Press",
                primaryBodyPart: .chest
            )
            let entry = ExerciseEntry(
                id: entryID,
                workoutSession: session,
                exercise: exercise,
                order: 2
            )
            let set = SetEntry(
                id: setID,
                exerciseEntry: entry,
                order: 3,
                weightKg: 82.5,
                reps: 7,
                isWarmup: true
            )
            context.insert(session)
            context.insert(exercise)
            context.insert(entry)
            context.insert(set)
            try context.save()
        }

        let localConfiguration = KASANEPersistenceCoordinator.localConfiguration(
            schema: schema,
            url: storeURL
        )
        let reopenedContainer = try ModelContainer(
            for: schema,
            migrationPlan: KASANEMigrationPlan.self,
            configurations: localConfiguration
        )
        let sessions = try reopenedContainer.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.id, sessionID)
        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.endedAt, endedAt)
        XCTAssertEqual(session.note, "existing workout")
        let entry = try XCTUnwrap(session.exerciseEntries.first)
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.order, 2)
        XCTAssertIdentical(entry.workoutSession, session)
        let exercise = try XCTUnwrap(entry.exercise)
        XCTAssertEqual(exercise.id, exerciseID)
        XCTAssertEqual(exercise.name, "Existing Bench Press")
        XCTAssertEqual(exercise.primaryBodyPart, BodyPart.chest.rawValue)
        XCTAssertEqual(exercise.exerciseEntries.map(\.id), [entryID])
        let set = try XCTUnwrap(entry.setEntries.first)
        XCTAssertEqual(set.id, setID)
        XCTAssertEqual(set.order, 3)
        XCTAssertEqual(set.weightKg, 82.5)
        XCTAssertEqual(set.reps, 7)
        XCTAssertTrue(set.isWarmup)
        XCTAssertIdentical(set.exerciseEntry, entry)
    }

    func testFreshInstallOpensWithoutSnapshotAndSavesMarker() throws {
        let harness = try Harness(storeExists: false)
        defer { harness.cleanup() }
        _ = try harness.coordinator().make()
        XCTAssertEqual(harness.marker.load(), 1)
        XCTAssertEqual(harness.snapshot.createCount, 0)
        XCTAssertEqual(harness.factoryCallCount, 1)
    }

    func testLegacyStoreCreatesSnapshotThenCleansUpAfterSuccess() throws {
        let harness = try Harness(storeExists: true)
        defer { harness.cleanup() }
        _ = try harness.coordinator().make()
        XCTAssertEqual(harness.snapshot.createCount, 1)
        XCTAssertEqual(harness.snapshot.deleteCount, 1)
        XCTAssertFalse(harness.snapshot.pending)
        XCTAssertEqual(harness.marker.load(), 1)
    }

    func testCurrentStoreDoesNotCreateSnapshot() throws {
        let harness = try Harness(storeExists: true, marker: 1)
        defer { harness.cleanup() }
        _ = try harness.coordinator().make()
        XCTAssertEqual(harness.snapshot.createCount, 0)
        XCTAssertEqual(harness.snapshot.restoreCount, 0)
    }

    func testPendingLegacySnapshotIsRestoredBeforeRetryAndNotOverwritten() throws {
        let harness = try Harness(storeExists: true, pending: true)
        defer { harness.cleanup() }
        _ = try harness.coordinator().make()
        XCTAssertEqual(harness.snapshot.restoreCount, 1)
        XCTAssertEqual(harness.snapshot.createCount, 0)
        XCTAssertEqual(harness.snapshot.deleteCount, 1)
    }

    func testCurrentMarkerWithPendingSnapshotDeletesWithoutRestore() throws {
        let harness = try Harness(storeExists: true, marker: 1, pending: true)
        defer { harness.cleanup() }
        _ = try harness.coordinator().make()
        XCTAssertEqual(harness.snapshot.restoreCount, 0)
        XCTAssertEqual(harness.snapshot.deleteCount, 1)
        XCTAssertEqual(harness.factoryCallCount, 1)
    }

    func testNewerPendingSnapshotIsPreservedWithoutOpeningStore() throws {
        let harness = try Harness(
            storeExists: true,
            marker: 1,
            pending: true,
            pendingTargetVersion: 2
        )
        defer { harness.cleanup() }

        XCTAssertThrowsError(try harness.coordinator().make()) { error in
            guard
                case .downgradeDetected(storedVersion: 2, currentVersion: 1) = error
                    as? KASANEPersistenceCoordinator.PersistenceError
            else { return XCTFail("unexpected error: \(error)") }
        }
        XCTAssertTrue(harness.snapshot.pending)
        XCTAssertEqual(harness.snapshot.restoreCount, 0)
        XCTAssertEqual(harness.snapshot.deleteCount, 0)
        XCTAssertEqual(harness.factoryCallCount, 0)
    }

    func testUnreadablePendingSnapshotIsPreservedWithoutOpeningStore() throws {
        let harness = try Harness(
            storeExists: true,
            marker: 1,
            pending: true,
            metadataError: TestError.metadata
        )
        defer { harness.cleanup() }

        XCTAssertThrowsError(try harness.coordinator().make()) { error in
            XCTAssertEqual(error as? TestError, .metadata)
        }
        XCTAssertTrue(harness.snapshot.pending)
        XCTAssertEqual(harness.snapshot.restoreCount, 0)
        XCTAssertEqual(harness.snapshot.deleteCount, 0)
        XCTAssertEqual(harness.factoryCallCount, 0)
    }

    func testOpenFailureRestoresSnapshotDoesNotAdvanceMarkerAndPropagatesError() throws {
        let harness = try Harness(storeExists: true, factoryError: TestError.open)
        defer { harness.cleanup() }
        XCTAssertThrowsError(try harness.coordinator().make()) { error in
            XCTAssertEqual(error as? TestError, .open)
        }
        XCTAssertEqual(harness.snapshot.restoreCount, 1)
        XCTAssertNil(harness.marker.load())
        XCTAssertTrue(harness.snapshot.pending)
    }

    func testRestoreFailurePreservesPendingAndReportsBothFailures() throws {
        let harness = try Harness(
            storeExists: true,
            pending: true,
            restoreError: TestError.restore,
            factoryError: TestError.open
        )
        defer { harness.cleanup() }
        // Recovery before opening fails, so opening must never start.
        XCTAssertThrowsError(try harness.coordinator().make()) { error in
            XCTAssertEqual(error as? TestError, .restore)
        }
        XCTAssertEqual(harness.factoryCallCount, 0)
        XCTAssertTrue(harness.snapshot.pending)

        // An open failure followed by a restore failure retains both underlying errors.
        harness.snapshot.restoreError = TestError.restore
        harness.snapshot.pending = false
        XCTAssertThrowsError(try harness.coordinator().make()) { error in
            guard
                case let KASANEPersistenceCoordinator.PersistenceError
                    .migrationAndRestoreFailed(migration, restore) = error
            else { return XCTFail("unexpected error: \(error)") }
            XCTAssertEqual(migration as? TestError, .open)
            XCTAssertEqual(restore as? TestError, .restore)
        }
        XCTAssertTrue(harness.snapshot.pending)
        XCTAssertNil(harness.marker.load())
    }

    func testSnapshotCreationFailureDoesNotOpenOrAdvanceMarker() throws {
        let harness = try Harness(storeExists: true, createError: TestError.snapshot)
        defer { harness.cleanup() }
        XCTAssertThrowsError(try harness.coordinator().make()) { error in
            XCTAssertEqual(error as? TestError, .snapshot)
        }
        XCTAssertEqual(harness.factoryCallCount, 0)
        XCTAssertNil(harness.marker.load())
    }

    func testDowngradeDoesNotOpenSnapshotOrChangeStoreAndMarker() throws {
        let harness = try Harness(storeExists: true, marker: 2)
        defer { harness.cleanup() }
        let before = try Data(contentsOf: harness.storeURL)
        XCTAssertThrowsError(try harness.coordinator().make()) { error in
            guard
                case .downgradeDetected(storedVersion: 2, currentVersion: 1) = error
                    as? KASANEPersistenceCoordinator.PersistenceError
            else { return XCTFail("unexpected error: \(error)") }
        }
        XCTAssertEqual(try Data(contentsOf: harness.storeURL), before)
        XCTAssertEqual(harness.marker.load(), 2)
        XCTAssertEqual(harness.factoryCallCount, 0)
        XCTAssertEqual(harness.snapshot.createCount, 0)
    }
}

private extension PersistenceCoordinatorTests {
    enum TestError: Error, Equatable {
        case open
        case metadata
        case restore
        case snapshot
    }

    final class SnapshotSpy: MigrationSnapshotStoring {
        var pending: Bool
        var sourceVersion: Int?
        var targetVersion: Int
        var metadataError: Error?
        var createError: Error?
        var restoreError: Error?
        var createCount = 0
        var restoreCount = 0
        var deleteCount = 0

        init(
            pending: Bool,
            sourceVersion: Int?,
            targetVersion: Int,
            metadataError: Error?,
            createError: Error?,
            restoreError: Error?
        ) {
            self.pending = pending
            self.sourceVersion = sourceVersion
            self.targetVersion = targetVersion
            self.metadataError = metadataError
            self.createError = createError
            self.restoreError = restoreError
        }

        func pendingSnapshotMetadata() throws -> MigrationSnapshotMetadata? {
            if let metadataError { throw metadataError }
            guard pending else { return nil }
            return MigrationSnapshotMetadata(
                sourceVersion: sourceVersion,
                targetVersion: targetVersion
            )
        }

        func createPendingSnapshot(storeURL: URL, sourceVersion: Int?, targetVersion: Int) throws {
            createCount += 1
            if let createError { throw createError }
            pending = true
            self.sourceVersion = sourceVersion
            self.targetVersion = targetVersion
        }

        func restorePendingSnapshot(storeURL: URL) throws {
            restoreCount += 1
            if let restoreError { throw restoreError }
        }

        func deletePendingSnapshot() throws {
            deleteCount += 1
            pending = false
        }
    }

    final class Harness {
        let directory: URL
        let storeURL: URL
        let defaults: UserDefaults
        let marker: SchemaVersionMarkerStore
        let snapshot: SnapshotSpy
        let configuration: ModelConfiguration
        let factoryError: Error?
        var factoryCallCount = 0

        init(
            storeExists: Bool,
            marker version: Int? = nil,
            pending: Bool = false,
            pendingTargetVersion: Int = 1,
            metadataError: Error? = nil,
            createError: Error? = nil,
            restoreError: Error? = nil,
            factoryError: Error? = nil
        ) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            storeURL = directory.appendingPathComponent("default.store")
            if storeExists { try Data("original store".utf8).write(to: storeURL) }
            let suiteName = "PersistenceCoordinatorTests.\(UUID().uuidString)"
            defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defaults.removePersistentDomain(forName: suiteName)
            marker = SchemaVersionMarkerStore(defaults: defaults)
            if let version { marker.save(version) }
            snapshot = SnapshotSpy(
                pending: pending,
                sourceVersion: version,
                targetVersion: pendingTargetVersion,
                metadataError: metadataError,
                createError: createError,
                restoreError: restoreError
            )
            let schema = Schema(versionedSchema: CurrentKASANESchema.self)
            configuration = ModelConfiguration(schema: schema, url: storeURL)
            self.factoryError = factoryError
        }

        @MainActor
        func coordinator() -> KASANEPersistenceCoordinator {
            KASANEPersistenceCoordinator(
                configuration: configuration,
                markerStore: marker,
                snapshotStore: snapshot
            ) { [self] schema, _ in
                factoryCallCount += 1
                if let factoryError { throw factoryError }
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                )
            }
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

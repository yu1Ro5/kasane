import Foundation
import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class PersistenceCoordinatorTests: XCTestCase {
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
        case restore
        case snapshot
    }

    final class SnapshotSpy: MigrationSnapshotStoring {
        var pending: Bool
        var createError: Error?
        var restoreError: Error?
        var createCount = 0
        var restoreCount = 0
        var deleteCount = 0

        init(pending: Bool, createError: Error?, restoreError: Error?) {
            self.pending = pending
            self.createError = createError
            self.restoreError = restoreError
        }

        func hasPendingSnapshot() -> Bool { pending }

        func createPendingSnapshot(storeURL: URL, sourceVersion: Int?, targetVersion: Int) throws {
            createCount += 1
            if let createError { throw createError }
            pending = true
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
                createError: createError,
                restoreError: restoreError
            )
            let schema = Schema(versionedSchema: CurrentKASANESchema.self)
            configuration = ModelConfiguration(schema: schema, url: storeURL)
            self.factoryError = factoryError
        }

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

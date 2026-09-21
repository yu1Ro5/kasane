import Foundation
import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class MigrationSnapshotStoreTests: XCTestCase {
    func testFailedSnapshotDoesNotPublishPendingDirectory() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")
        try Data("main".utf8).write(to: storeURL)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))
        let snapshot = MigrationSnapshotStore(
            rootURL: directory.appendingPathComponent("snapshots"),
            fileManager: FailingCopyFileManager()
        )

        XCTAssertThrowsError(
            try snapshot.createPendingSnapshot(storeURL: storeURL, sourceVersion: nil, targetVersion: 1)
        )
        XCTAssertNil(try snapshot.pendingSnapshotMetadata())
    }

    func testSnapshotAndRestorePreserveMainStoreAndEveryExistingSidecar() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")
        let snapshot = MigrationSnapshotStore(
            rootURL: directory.appendingPathComponent("snapshots"),
            now: { Date(timeIntervalSince1970: 123) }
        )
        let original = ["": "main", "-wal": "wal", "-shm": "shm", "-journal": "journal"]
        for (suffix, contents) in original {
            try Data(contents.utf8).write(to: URL(fileURLWithPath: storeURL.path + suffix))
        }

        try snapshot.createPendingSnapshot(storeURL: storeURL, sourceVersion: nil, targetVersion: 1)
        XCTAssertEqual(
            try snapshot.pendingSnapshotMetadata(),
            MigrationSnapshotMetadata(sourceVersion: nil, targetVersion: 1)
        )
        XCTAssertThrowsError(
            try snapshot.createPendingSnapshot(storeURL: storeURL, sourceVersion: nil, targetVersion: 1)
        )
        for suffix in original.keys {
            try Data("changed".utf8).write(to: URL(fileURLWithPath: storeURL.path + suffix))
        }
        try Data("new sidecar".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-other"))
        try snapshot.restorePendingSnapshot(storeURL: storeURL)

        for (suffix, contents) in original {
            XCTAssertEqual(
                try String(contentsOf: URL(fileURLWithPath: storeURL.path + suffix), encoding: .utf8),
                contents
            )
        }
        try snapshot.deletePendingSnapshot()
        XCTAssertNil(try snapshot.pendingSnapshotMetadata())
    }

    func testRestoreRemovesSidecarThatDidNotExistAtSnapshotTime() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")
        try Data("main".utf8).write(to: storeURL)
        let snapshot = MigrationSnapshotStore(rootURL: directory.appendingPathComponent("snapshots"))
        try snapshot.createPendingSnapshot(storeURL: storeURL, sourceVersion: nil, targetVersion: 1)
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        try Data("migration wal".utf8).write(to: walURL)
        try snapshot.restorePendingSnapshot(storeURL: storeURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: walURL.path))
    }

    func testPendingDirectoryWithoutManifestIsPreservedAndReported() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = MigrationSnapshotStore(rootURL: directory.appendingPathComponent("snapshots"))
        try FileManager.default.createDirectory(
            at: snapshot.pendingURL,
            withIntermediateDirectories: true
        )

        XCTAssertThrowsError(try snapshot.pendingSnapshotMetadata()) { error in
            guard case MigrationSnapshotStore.SnapshotError.missingManifest = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshot.pendingURL.path))
    }

    func testRestoredDiskStoreReopensWithOriginalValuesAndRelationships() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")
        let schema = Schema(versionedSchema: CurrentKASANESchema.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let sessionID = try XCTUnwrap(
            UUID(uuidString: "10000000-0000-4000-8000-000000000001")
        )
        let exerciseID = try XCTUnwrap(
            UUID(uuidString: "20000000-0000-4000-8000-000000000001")
        )
        let entryID = try XCTUnwrap(
            UUID(uuidString: "30000000-0000-4000-8000-000000000001")
        )
        let setID = try XCTUnwrap(
            UUID(uuidString: "40000000-0000-4000-8000-000000000001")
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: KASANEMigrationPlan.self,
                configurations: configuration
            )
            let session = WorkoutSession(
                id: sessionID,
                startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                endedAt: Date(timeIntervalSince1970: 1_700_003_600),
                note: "original note"
            )
            let exercise = Exercise(
                id: exerciseID,
                name: "Original Press",
                primaryBodyPart: .chest
            )
            let entry = ExerciseEntry(
                id: entryID,
                workoutSession: session,
                exercise: exercise,
                order: 0
            )
            let set = SetEntry(
                id: setID,
                exerciseEntry: entry,
                order: 0,
                weightKg: 80,
                reps: 8
            )
            container.mainContext.insert(session)
            container.mainContext.insert(exercise)
            container.mainContext.insert(entry)
            container.mainContext.insert(set)
            try container.mainContext.save()
        }

        let snapshot = MigrationSnapshotStore(
            rootURL: directory.appendingPathComponent("snapshots")
        )
        try snapshot.createPendingSnapshot(
            storeURL: storeURL,
            sourceVersion: 1,
            targetVersion: 2
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: KASANEMigrationPlan.self,
                configurations: configuration
            )
            let session = try XCTUnwrap(
                container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
            )
            session.note = "changed note"
            let entry = try XCTUnwrap(session.exerciseEntries.first)
            entry.exercise?.name = "Changed Press"
            entry.setEntries.first?.weightKg = 120
            try container.mainContext.save()
        }

        try snapshot.restorePendingSnapshot(storeURL: storeURL)

        let restoredContainer = try ModelContainer(
            for: schema,
            migrationPlan: KASANEMigrationPlan.self,
            configurations: configuration
        )
        let restoredSession = try XCTUnwrap(
            restoredContainer.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first
        )
        XCTAssertEqual(restoredSession.id, sessionID)
        XCTAssertEqual(restoredSession.note, "original note")
        let restoredEntry = try XCTUnwrap(restoredSession.exerciseEntries.first)
        XCTAssertEqual(restoredEntry.id, entryID)
        XCTAssertIdentical(restoredEntry.workoutSession, restoredSession)
        let restoredExercise = try XCTUnwrap(restoredEntry.exercise)
        XCTAssertEqual(restoredExercise.id, exerciseID)
        XCTAssertEqual(restoredExercise.name, "Original Press")
        XCTAssertEqual(restoredExercise.exerciseEntries.map(\.id), [entryID])
        let restoredSet = try XCTUnwrap(restoredEntry.setEntries.first)
        XCTAssertEqual(restoredSet.id, setID)
        XCTAssertEqual(restoredSet.weightKg, 80)
        XCTAssertEqual(restoredSet.reps, 8)
        XCTAssertIdentical(restoredSet.exerciseEntry, restoredEntry)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class FailingCopyFileManager: FileManager, @unchecked Sendable {
    private var copyCount = 0

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copyCount += 1
        if copyCount == 2 { throw CocoaError(.fileWriteUnknown) }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}

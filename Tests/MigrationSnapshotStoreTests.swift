import Foundation
import XCTest

@testable import KASANE

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
        XCTAssertFalse(snapshot.hasPendingSnapshot())
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
        XCTAssertTrue(snapshot.hasPendingSnapshot())
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
        XCTAssertFalse(snapshot.hasPendingSnapshot())
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

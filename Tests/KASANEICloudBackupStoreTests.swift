import Foundation
import XCTest

@testable import KASANE

final class KASANEICloudBackupStoreTests: XCTestCase {
    func testSaveAtomicallyOverwritesOnlyLatestBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KASANEICloudBackupStore(
            containerURLProvider: { root },
            isICloudAvailable: { true },
            requiresUbiquitousDownload: false
        )

        try await store.save(Data("old".utf8))
        try await store.save(Data("new".utf8))

        let latest = try await store.loadLatest()
        XCTAssertEqual(latest, Data("new".utf8))
        let directory = root.appending(path: "Documents/KASANE/Backups")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["latest.json"])
    }

    func testMissingLatestIsNotAnUnavailableContainer() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KASANEICloudBackupStore(
            containerURLProvider: { root },
            isICloudAvailable: { true },
            requiresUbiquitousDownload: false
        )

        let latestBackupExists = try await store.latestBackupExists()
        XCTAssertFalse(latestBackupExists)
        await XCTAssertThrowsErrorAsync(try await store.loadLatest()) { error in
            XCTAssertEqual(error as? KASANEICloudBackupStoreError, .backupNotFound)
        }
    }

    func testUnavailableICloudAndMissingContainerAreExplicitErrors() async {
        let unavailable = KASANEICloudBackupStore(
            containerURLProvider: { nil },
            isICloudAvailable: { false }
        )
        await XCTAssertThrowsErrorAsync(try await unavailable.latestBackupExists()) { error in
            XCTAssertEqual(error as? KASANEICloudBackupStoreError, .unavailable)
        }

        let missingContainer = KASANEICloudBackupStore(
            containerURLProvider: { nil },
            isICloudAvailable: { true }
        )
        await XCTAssertThrowsErrorAsync(try await missingContainer.latestBackupExists()) { error in
            XCTAssertEqual(error as? KASANEICloudBackupStoreError, .containerUnavailable)
        }
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

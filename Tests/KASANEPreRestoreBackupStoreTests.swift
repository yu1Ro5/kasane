import Foundation
import XCTest

@testable import KASANE

final class KASANEPreRestoreBackupStoreTests: XCTestCase {
    func testSaveUsesSingleAtomicLatestFileAndPreservesBackupPayload() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KASANEPreRestoreBackupStore(applicationSupportURLProvider: { root })
        let backup = BackupTestFixture.backup()

        try await store.save(KASANEBackupCoding.encode(backup))

        let directory = root.appending(path: "KASANE/RestoreSafety")
        let url = directory.appending(path: "pre-restore-latest.json")
        XCTAssertEqual(try KASANEBackupCoding.decode(Data(contentsOf: url)), backup)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["pre-restore-latest.json"])
    }
}

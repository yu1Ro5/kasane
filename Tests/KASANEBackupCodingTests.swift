import Foundation
import XCTest

@testable import KASANE

final class KASANEBackupCodingTests: XCTestCase {
    func testEncodeDecodeRoundTripUsesISO8601PrettyPrintedSortedJSON() throws {
        let backup = BackupTestFixture.backup()
        let data = try KASANEBackupCoding.encode(backup)

        XCTAssertEqual(try KASANEBackupCoding.decode(data), backup)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\n"))
        XCTAssertTrue(json.contains("2023-11-14T22:13:20.125Z"))
        let appVersionIndex = try XCTUnwrap(json.range(of: "\"appVersion\"")?.lowerBound)
        let exportedAtIndex = try XCTUnwrap(json.range(of: "\"exportedAt\"")?.lowerBound)
        XCTAssertLessThan(appVersionIndex, exportedAtIndex)
    }

    func testInvalidJSONCannotBeDecoded() {
        XCTAssertThrowsError(try KASANEBackupCoding.decode(Data("not json".utf8)))
    }
}

enum BackupTestFixture {
    static let exerciseID = UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID()
    static let workoutID = UUID(uuidString: "10000000-0000-4000-8000-000000000001") ?? UUID()
    static let entryID = UUID(uuidString: "20000000-0000-4000-8000-000000000001") ?? UUID()
    static let setID = UUID(uuidString: "30000000-0000-4000-8000-000000000001") ?? UUID()

    static func backup(
        formatVersion: Int = 1,
        exerciseIDOverride: UUID? = exerciseID,
        weight: Double = 50,
        reps: Int = 8
    ) -> KASANEBackup {
        KASANEBackup(
            formatVersion: formatVersion,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000.125),
            appVersion: "1.2.3",
            exercises: [
                ExerciseBackup(id: exerciseID, name: "ベンチプレス", primaryBodyPart: "chest", isArchived: false)
            ],
            workouts: [
                WorkoutBackup(
                    id: workoutID,
                    startedAt: Date(timeIntervalSince1970: 1_699_999_000),
                    endedAt: Date(timeIntervalSince1970: 1_699_999_600),
                    note: "好調",
                    exerciseEntries: [
                        ExerciseEntryBackup(
                            id: entryID,
                            exerciseID: exerciseIDOverride,
                            exerciseNameSnapshot: "ベンチプレス",
                            primaryBodyPartSnapshot: "chest",
                            order: 0,
                            sets: [SetEntryBackup(id: setID, order: 0, weightKg: weight, reps: reps, isWarmup: true)]
                        )
                    ]
                )
            ]
        )
    }
}

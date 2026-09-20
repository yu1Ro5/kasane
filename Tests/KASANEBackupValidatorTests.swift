import Foundation
import XCTest

@testable import KASANE

final class KASANEBackupValidatorTests: XCTestCase {
    func testAcceptsValidBackupAndNilExerciseRelationship() throws {
        try KASANEBackupValidator.validate(BackupTestFixture.backup(exerciseIDOverride: nil))
    }

    func testRejectsUnsupportedVersion() {
        assertInvalid(BackupTestFixture.backup(formatVersion: 2))
    }

    func testRejectsDuplicateIDs() {
        let base = BackupTestFixture.backup()
        assertInvalid(copy(base, exercises: base.exercises + base.exercises))
        assertInvalid(copy(base, workouts: base.workouts + base.workouts))

        let secondWorkout = WorkoutBackup(
            id: UUID(), startedAt: Date(), endedAt: Date(), note: nil,
            exerciseEntries: base.workouts[0].exerciseEntries)
        assertInvalid(copy(base, workouts: base.workouts + [secondWorkout]))

        let entry = base.workouts[0].exerciseEntries[0]
        let secondEntry = ExerciseEntryBackup(
            id: UUID(), exerciseID: entry.exerciseID, exerciseNameSnapshot: entry.exerciseNameSnapshot,
            primaryBodyPartSnapshot: entry.primaryBodyPartSnapshot, order: 1, sets: entry.sets)
        let workout = copy(base.workouts[0], entries: [entry, secondEntry])
        assertInvalid(copy(base, workouts: [workout]))
    }

    func testRejectsBrokenRelationshipAndInvalidSetValues() {
        assertInvalid(BackupTestFixture.backup(exerciseIDOverride: UUID()))
        assertInvalid(BackupTestFixture.backup(weight: .nan))
        assertInvalid(BackupTestFixture.backup(weight: .infinity))
        assertInvalid(BackupTestFixture.backup(weight: -1))
        assertInvalid(BackupTestFixture.backup(reps: 0))
    }

    func testRejectsNegativeAndDuplicateOrders() {
        let base = BackupTestFixture.backup()
        let entry = base.workouts[0].exerciseEntries[0]
        let negativeEntry = ExerciseEntryBackup(
            id: entry.id, exerciseID: entry.exerciseID, exerciseNameSnapshot: entry.exerciseNameSnapshot,
            primaryBodyPartSnapshot: entry.primaryBodyPartSnapshot, order: -1, sets: entry.sets)
        assertInvalid(copy(base, workouts: [copy(base.workouts[0], entries: [negativeEntry])]))

        let duplicateOrderEntry = ExerciseEntryBackup(
            id: UUID(), exerciseID: entry.exerciseID, exerciseNameSnapshot: entry.exerciseNameSnapshot,
            primaryBodyPartSnapshot: entry.primaryBodyPartSnapshot, order: 0, sets: [])
        assertInvalid(copy(base, workouts: [copy(base.workouts[0], entries: [entry, duplicateOrderEntry])]))
        let duplicateSet = SetEntryBackup(id: UUID(), order: 0, weightKg: 1, reps: 1, isWarmup: false)
        let badSets = ExerciseEntryBackup(
            id: entry.id, exerciseID: entry.exerciseID, exerciseNameSnapshot: entry.exerciseNameSnapshot,
            primaryBodyPartSnapshot: entry.primaryBodyPartSnapshot, order: 0, sets: entry.sets + [duplicateSet])
        assertInvalid(copy(base, workouts: [copy(base.workouts[0], entries: [badSets])]))
    }

    private func assertInvalid(_ backup: KASANEBackup, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try KASANEBackupValidator.validate(backup), file: file, line: line)
    }

    private func copy(_ backup: KASANEBackup, exercises: [ExerciseBackup]? = nil, workouts: [WorkoutBackup]? = nil)
        -> KASANEBackup
    {
        KASANEBackup(
            formatVersion: backup.formatVersion, exportedAt: backup.exportedAt, appVersion: backup.appVersion,
            exercises: exercises ?? backup.exercises, workouts: workouts ?? backup.workouts)
    }

    private func copy(_ workout: WorkoutBackup, entries: [ExerciseEntryBackup]) -> WorkoutBackup {
        WorkoutBackup(
            id: workout.id, startedAt: workout.startedAt, endedAt: workout.endedAt, note: workout.note,
            exerciseEntries: entries)
    }
}

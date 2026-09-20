import Foundation

enum KASANEBackupValidationError: Error, Equatable, LocalizedError {
    case unsupportedFormatVersion(Int)
    case duplicateExerciseID(UUID)
    case duplicateWorkoutID(UUID)
    case duplicateExerciseEntryID(UUID)
    case duplicateSetEntryID(UUID)
    case missingExercise(UUID)
    case invalidExerciseEntryOrder(Int)
    case duplicateExerciseEntryOrder(Int)
    case invalidSetOrder(Int)
    case duplicateSetOrder(Int)
    case nonFiniteWeight
    case negativeWeight
    case invalidReps(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion: "このバックアップ形式には対応していません。"
        default: "バックアップの内容が不正です。"
        }
    }
}

enum KASANEBackupValidator {
    static func validate(_ backup: KASANEBackup) throws {
        guard backup.formatVersion == KASANEBackup.currentFormatVersion else {
            throw KASANEBackupValidationError.unsupportedFormatVersion(backup.formatVersion)
        }
        try ensureUnique(backup.exercises.map(\.id), error: KASANEBackupValidationError.duplicateExerciseID)
        try ensureUnique(backup.workouts.map(\.id), error: KASANEBackupValidationError.duplicateWorkoutID)

        let exerciseIDs = Set(backup.exercises.map(\.id))
        var entryIDs = Set<UUID>()
        var setIDs = Set<UUID>()
        for workout in backup.workouts {
            var orders = Set<Int>()
            for entry in workout.exerciseEntries {
                guard entryIDs.insert(entry.id).inserted else {
                    throw KASANEBackupValidationError.duplicateExerciseEntryID(entry.id)
                }
                if let exerciseID = entry.exerciseID, !exerciseIDs.contains(exerciseID) {
                    throw KASANEBackupValidationError.missingExercise(exerciseID)
                }
                guard entry.order >= 0 else {
                    throw KASANEBackupValidationError.invalidExerciseEntryOrder(entry.order)
                }
                guard orders.insert(entry.order).inserted else {
                    throw KASANEBackupValidationError.duplicateExerciseEntryOrder(entry.order)
                }
                var setOrders = Set<Int>()
                for set in entry.sets {
                    guard setIDs.insert(set.id).inserted else {
                        throw KASANEBackupValidationError.duplicateSetEntryID(set.id)
                    }
                    guard set.order >= 0 else {
                        throw KASANEBackupValidationError.invalidSetOrder(set.order)
                    }
                    guard setOrders.insert(set.order).inserted else {
                        throw KASANEBackupValidationError.duplicateSetOrder(set.order)
                    }
                    guard set.weightKg.isFinite else {
                        throw KASANEBackupValidationError.nonFiniteWeight
                    }
                    guard set.weightKg >= 0 else {
                        throw KASANEBackupValidationError.negativeWeight
                    }
                    guard set.reps >= 1 else {
                        throw KASANEBackupValidationError.invalidReps(set.reps)
                    }
                }
            }
        }
    }

    private static func ensureUnique(
        _ ids: [UUID],
        error: (UUID) -> KASANEBackupValidationError
    ) throws {
        var seen = Set<UUID>()
        for id in ids where !seen.insert(id).inserted { throw error(id) }
    }
}

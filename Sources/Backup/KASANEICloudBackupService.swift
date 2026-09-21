import Foundation
import SwiftData

struct KASANEBackupSummary: Equatable, Sendable {
    let exportedAt: Date
    let appVersion: String
    let workoutCount: Int
    let exerciseCount: Int
    let setCount: Int

    init(backup: KASANEBackup) {
        exportedAt = backup.exportedAt
        appVersion = backup.appVersion
        workoutCount = backup.workouts.count
        exerciseCount = backup.exercises.count
        setCount = backup.workouts.reduce(0) { workoutTotal, workout in
            workoutTotal + workout.exerciseEntries.reduce(0) { $0 + $1.sets.count }
        }
    }
}

struct KASANEPreparedICloudRestore: Equatable, Identifiable, Sendable {
    let backup: KASANEBackup
    let summary: KASANEBackupSummary

    var id: Date { backup.exportedAt }
}

enum KASANEICloudBackupServiceError: Error, Equatable {
    case iCloudUnavailable
    case containerUnavailable
    case backupNotFound
    case downloadFailed
    case downloadTimedOut
    case readFailed
    case writeFailed
    case invalidJSON
    case unsupportedFormatVersion
    case invalidBackup
    case safetyBackupFailed
    case workoutInProgress
    case importFailed
    case exportFailed
}

@MainActor
struct KASANEICloudBackupService {
    let container: ModelContainer
    let cloudStore: any KASANECloudBackupStoring
    let safetyStore: any KASANEPreRestoreBackupStoring
    var beforeImportCommit: (ModelContext) throws -> Void = { _ in }

    @discardableResult
    func backupNow(now: Date = Date()) async throws -> KASANEBackupSummary {
        let backup: KASANEBackup
        let data: Data
        do {
            backup = try KASANEBackupExporter(container: container).makeBackup(now: now)
            data = try KASANEBackupCoding.encode(backup)
        } catch {
            throw KASANEICloudBackupServiceError.exportFailed
        }
        do {
            try await cloudStore.save(data)
        } catch {
            throw mapStoreError(error)
        }
        return KASANEBackupSummary(backup: backup)
    }

    func latestBackupSummary() async throws -> KASANEBackupSummary? {
        do {
            guard try await cloudStore.latestBackupExists() else { return nil }
        } catch {
            throw mapStoreError(error)
        }
        return try await prepareRestore().summary
    }

    func prepareRestore() async throws -> KASANEPreparedICloudRestore {
        let data: Data
        do {
            data = try await cloudStore.loadLatest()
        } catch {
            throw mapStoreError(error)
        }
        let backup: KASANEBackup
        do {
            backup = try KASANEBackupCoding.decode(data)
        } catch {
            throw KASANEICloudBackupServiceError.invalidJSON
        }
        do {
            try KASANEBackupValidator.validate(backup)
        } catch let error as KASANEBackupValidationError {
            if case .unsupportedFormatVersion = error {
                throw KASANEICloudBackupServiceError.unsupportedFormatVersion
            }
            throw KASANEICloudBackupServiceError.invalidBackup
        }
        return KASANEPreparedICloudRestore(
            backup: backup,
            summary: KASANEBackupSummary(backup: backup)
        )
    }

    func restore(_ prepared: KASANEPreparedICloudRestore, now: Date = Date()) async throws {
        do {
            try KASANEBackupValidator.validate(prepared.backup)
        } catch let error as KASANEBackupValidationError {
            if case .unsupportedFormatVersion = error {
                throw KASANEICloudBackupServiceError.unsupportedFormatVersion
            }
            throw KASANEICloudBackupServiceError.invalidBackup
        }

        let safetyData: Data
        do {
            safetyData = try KASANEBackupExporter(container: container).makeJSONData(now: now)
            try await safetyStore.save(safetyData)
        } catch {
            throw KASANEICloudBackupServiceError.safetyBackupFailed
        }

        do {
            try KASANEBackupImporter(
                container: container,
                beforeCommit: beforeImportCommit
            ).importBackup(prepared.backup)
        } catch KASANEBackupImportError.workoutInProgress {
            throw KASANEICloudBackupServiceError.workoutInProgress
        } catch {
            throw KASANEICloudBackupServiceError.importFailed
        }
    }

    private func mapStoreError(_ error: Error) -> KASANEICloudBackupServiceError {
        guard let error = error as? KASANEICloudBackupStoreError else {
            return .readFailed
        }
        switch error {
        case .unavailable: return .iCloudUnavailable
        case .containerUnavailable: return .containerUnavailable
        case .backupNotFound: return .backupNotFound
        case .downloadFailed: return .downloadFailed
        case .downloadTimedOut: return .downloadTimedOut
        case .readFailed: return .readFailed
        case .writeFailed: return .writeFailed
        }
    }
}

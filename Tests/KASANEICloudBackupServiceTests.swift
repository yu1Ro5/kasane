import Foundation
import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class KASANEICloudBackupServiceTests: XCTestCase {
    func testBackupExportsExistingFormatToCloudStore() async throws {
        let container = try makeContainer(withLocalFixture: true)
        let cloud = MemoryCloudStore()
        let service = makeService(container: container, cloud: cloud)
        let now = Date(timeIntervalSince1970: 2_000)

        let summary = try await service.backupNow(now: now)
        let storedData = await cloud.data
        let backup = try KASANEBackupCoding.decode(try XCTUnwrap(storedData))

        XCTAssertEqual(backup.formatVersion, KASANEBackup.currentFormatVersion)
        XCTAssertEqual(backup.exportedAt, now)
        XCTAssertEqual(summary.exportedAt, backup.exportedAt)
        XCTAssertEqual(backup.workouts.count, 1)
        XCTAssertEqual(backup.exercises.count, 1)
    }

    func testLatestSummaryUsesExportedAtAndCountsNestedSets() async throws {
        let backup = BackupTestFixture.backup()
        let cloud = MemoryCloudStore(data: try KASANEBackupCoding.encode(backup))
        let service = makeService(container: try makeContainer(), cloud: cloud)

        let latestSummary = try await service.latestBackupSummary()
        let summary = try XCTUnwrap(latestSummary)

        XCTAssertEqual(summary.exportedAt, backup.exportedAt)
        XCTAssertEqual(summary.appVersion, "1.2.3")
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.exerciseCount, 1)
        XCTAssertEqual(summary.setCount, 1)
    }

    func testNoBackupReturnsNilSeparatelyFromUnavailable() async throws {
        let container = try makeContainer()
        let noBackup = makeService(container: container, cloud: MemoryCloudStore())
        let summary = try await noBackup.latestBackupSummary()
        XCTAssertNil(summary)

        let unavailable = makeService(
            container: container,
            cloud: MemoryCloudStore(error: KASANEICloudBackupStoreError.unavailable)
        )
        await assertServiceError(.iCloudUnavailable) {
            _ = try await unavailable.latestBackupSummary()
        }
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<WorkoutSession>()), 0)
    }

    func testInvalidJSONAndUnsupportedVersionDoNotPrepareOrImport() async throws {
        let container = try makeContainer(withLocalFixture: true)
        let invalid = makeService(
            container: container,
            cloud: MemoryCloudStore(data: Data("broken".utf8))
        )
        await assertServiceError(.invalidJSON) { _ = try await invalid.prepareRestore() }

        let unsupportedData = try KASANEBackupCoding.encode(
            BackupTestFixture.backup(formatVersion: 2)
        )
        let unsupported = makeService(
            container: container,
            cloud: MemoryCloudStore(data: unsupportedData)
        )
        await assertServiceError(.unsupportedFormatVersion) {
            _ = try await unsupported.prepareRestore()
        }
        try assertLocalFixtureRemains(container)
    }

    func testSafetyBackupFailurePreventsImport() async throws {
        let container = try makeContainer(withLocalFixture: true)
        let cloud = MemoryCloudStore(data: try KASANEBackupCoding.encode(BackupTestFixture.backup()))
        let service = makeService(
            container: container,
            cloud: cloud,
            safety: FailingSafetyStore()
        )
        let prepared = try await service.prepareRestore()

        await assertServiceError(.safetyBackupFailed) { try await service.restore(prepared) }
        try assertLocalFixtureRemains(container)
    }

    func testRestoreReplacesLocalDataAndSafetyBackupPreservesEveryValue() async throws {
        let container = try makeContainer(withLocalFixture: true)
        let cloudBackup = BackupTestFixture.backup()
        let cloud = MemoryCloudStore(data: try KASANEBackupCoding.encode(cloudBackup))
        let safety = MemorySafetyStore()
        let service = makeService(container: container, cloud: cloud, safety: safety)

        try await service.restore(try await service.prepareRestore(), now: Date(timeIntervalSince1970: 4_000))

        let restored = try KASANEBackupExporter(container: container).makeBackup(now: cloudBackup.exportedAt)
        XCTAssertEqual(restored.formatVersion, cloudBackup.formatVersion)
        XCTAssertEqual(restored.exportedAt, cloudBackup.exportedAt)
        XCTAssertEqual(restored.appVersion, AppVersion.current)
        XCTAssertEqual(restored.exercises, cloudBackup.exercises)
        XCTAssertEqual(restored.workouts, cloudBackup.workouts)
        let storedSafetyData = await safety.data
        let safetyBackup = try KASANEBackupCoding.decode(try XCTUnwrap(storedSafetyData))
        XCTAssertEqual(safetyBackup.exercises.first?.id, localExerciseID)
        XCTAssertEqual(safetyBackup.workouts.first?.id, localWorkoutID)
        XCTAssertEqual(safetyBackup.workouts.first?.note, "local note")
        let entry = try XCTUnwrap(safetyBackup.workouts.first?.exerciseEntries.first)
        XCTAssertEqual(entry.id, localEntryID)
        XCTAssertEqual(entry.exerciseID, localExerciseID)
        XCTAssertEqual(entry.exerciseNameSnapshot, "local snapshot")
        XCTAssertEqual(entry.primaryBodyPartSnapshot, "local-body")
        XCTAssertEqual(entry.order, 3)
        let set = try XCTUnwrap(entry.sets.first)
        XCTAssertEqual(set.id, localSetID)
        XCTAssertEqual(set.weightKg, 22.5)
        XCTAssertEqual(set.reps, 7)
        XCTAssertEqual(set.order, 2)
    }

    func testImporterFailureRollsBackWhileKeepingSafetyBackup() async throws {
        enum Injected: Error { case failed }
        let container = try makeContainer(withLocalFixture: true)
        let safety = MemorySafetyStore()
        var service = makeService(
            container: container,
            cloud: MemoryCloudStore(data: try KASANEBackupCoding.encode(BackupTestFixture.backup())),
            safety: safety
        )
        service.beforeImportCommit = { _ in throw Injected.failed }
        let prepared = try await service.prepareRestore()

        await assertServiceError(.importFailed) { try await service.restore(prepared) }

        try assertLocalFixtureRemains(container)
        let storedSafetyData = await safety.data
        XCTAssertNotNil(storedSafetyData)
        let context = ModelContext(container)
        XCTAssertFalse(
            try context.fetch(FetchDescriptor<WorkoutSession>()).contains { $0.id == BackupTestFixture.workoutID })
    }

    func testOngoingWorkoutRejectsRestoreWithoutChangingData() async throws {
        let container = try makeContainer()
        container.mainContext.insert(WorkoutSession(startedAt: Date(timeIntervalSince1970: 10)))
        try container.mainContext.save()
        let safety = MemorySafetyStore()
        let service = makeService(
            container: container,
            cloud: MemoryCloudStore(data: try KASANEBackupCoding.encode(BackupTestFixture.backup())),
            safety: safety
        )

        await assertServiceError(.workoutInProgress) {
            try await service.restore(try await service.prepareRestore())
        }

        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<WorkoutSession>()), 1)
        let storedSafetyData = await safety.data
        let saveCallCount = await safety.saveCallCount
        XCTAssertNil(storedSafetyData)
        XCTAssertEqual(saveCallCount, 0)
    }

    private func makeService(
        container: ModelContainer,
        cloud: any KASANECloudBackupStoring,
        safety: any KASANEPreRestoreBackupStoring = MemorySafetyStore()
    ) -> KASANEICloudBackupService {
        KASANEICloudBackupService(container: container, cloudStore: cloud, safetyStore: safety)
    }

    private func makeContainer(withLocalFixture: Bool = false) throws -> ModelContainer {
        let schema = Schema([WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        guard withLocalFixture else { return container }
        let exercise = Exercise(id: localExerciseID, name: "local", primaryBodyPart: .other)
        let workout = WorkoutSession(
            id: localWorkoutID,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            note: "local note"
        )
        let entry = ExerciseEntry(
            id: localEntryID,
            workoutSession: workout,
            exercise: exercise,
            order: 3
        )
        entry.exerciseNameSnapshot = "local snapshot"
        entry.primaryBodyPartSnapshot = "local-body"
        container.mainContext.insert(exercise)
        container.mainContext.insert(workout)
        container.mainContext.insert(entry)
        container.mainContext.insert(
            SetEntry(
                id: localSetID,
                exerciseEntry: entry,
                order: 2,
                weightKg: 22.5,
                reps: 7,
                isWarmup: true
            )
        )
        try container.mainContext.save()
        return container
    }

    private func assertLocalFixtureRemains(_ container: ModelContainer) throws {
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).map(\.id), [localExerciseID])
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).map(\.id), [localWorkoutID])
    }

    private func assertServiceError(
        _ expected: KASANEICloudBackupServiceError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch {
            XCTAssertEqual(error as? KASANEICloudBackupServiceError, expected)
        }
    }

    private let localExerciseID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001") ?? UUID()
    private let localWorkoutID = UUID(uuidString: "A0000000-0000-4000-8000-000000000002") ?? UUID()
    private let localEntryID = UUID(uuidString: "A0000000-0000-4000-8000-000000000003") ?? UUID()
    private let localSetID = UUID(uuidString: "A0000000-0000-4000-8000-000000000004") ?? UUID()
}

private actor MemoryCloudStore: KASANECloudBackupStoring {
    var data: Data?
    let error: KASANEICloudBackupStoreError?

    init(data: Data? = nil, error: KASANEICloudBackupStoreError? = nil) {
        self.data = data
        self.error = error
    }

    func save(_ data: Data) throws {
        if let error { throw error }
        self.data = data
    }

    func loadLatest() throws -> Data {
        if let error { throw error }
        guard let data else { throw KASANEICloudBackupStoreError.backupNotFound }
        return data
    }

    func latestBackupExists() throws -> Bool {
        if let error { throw error }
        return data != nil
    }
}

private actor MemorySafetyStore: KASANEPreRestoreBackupStoring {
    var data: Data?
    private(set) var saveCallCount = 0

    func save(_ data: Data) {
        self.data = data
        saveCallCount += 1
    }
}

private struct FailingSafetyStore: KASANEPreRestoreBackupStoring {
    struct Failure: Error {}
    func save(_ data: Data) async throws { throw Failure() }
}

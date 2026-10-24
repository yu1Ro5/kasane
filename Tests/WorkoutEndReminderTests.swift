import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class WorkoutEndReminderTests: XCTestCase {
    private final class Clock {
        var now: Date

        init(_ now: Date) {
            self.now = now
        }
    }

    private final class FakeNotificationCenter: WorkoutEndReminderNotificationCenter {
        struct AddedReminder: Equatable {
            let identifier: String
            let workoutID: UUID
            let fireDate: Date
        }

        var status: WorkoutEndReminderAuthorizationStatus = .authorized
        var requestAuthorizationResult = true
        var added: [AddedReminder] = []
        var pending: Set<String> = []
        var removedPending: [String] = []
        var removedDelivered: [String] = []
        var onAdd: (() async -> Void)?

        func authorizationStatus() async -> WorkoutEndReminderAuthorizationStatus { status }

        func requestAuthorization() async throws -> Bool {
            status = requestAuthorizationResult ? .authorized : .denied
            return requestAuthorizationResult
        }

        func pendingRequestIdentifiers() async -> Set<String> { pending }

        func addReminder(identifier: String, workoutID: UUID, fireDate: Date) async throws {
            if let onAdd {
                self.onAdd = nil
                await onAdd()
            }
            added.append(
                AddedReminder(identifier: identifier, workoutID: workoutID, fireDate: fireDate)
            )
            pending.insert(identifier)
        }

        func removePendingRequests(withIdentifiers identifiers: [String]) {
            removedPending.append(contentsOf: identifiers)
            pending.subtract(identifiers)
        }

        func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
            removedDelivered.append(contentsOf: identifiers)
        }
    }

    private func makePreferences() throws -> (WorkoutEndReminderPreferences, String) {
        let suiteName = "WorkoutEndReminderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (WorkoutEndReminderPreferences(defaults: defaults), suiteName)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    func testReminderDetectionStartsAtSixHours() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSession(startedAt: startedAt)

        XCTAssertFalse(
            WorkoutEndReminderPolicy.isOverdue(
                session,
                at: startedAt.addingTimeInterval(5 * 60 * 60 + 59 * 60)
            )
        )
        XCTAssertTrue(
            WorkoutEndReminderPolicy.isOverdue(
                session,
                at: startedAt.addingTimeInterval(6 * 60 * 60)
            )
        )
    }

    func testSchedulesSixAndEightHourNotificationsWithoutDuplicates() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let clock = Clock(startedAt)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { clock.now }
        )
        let session = WorkoutSession(startedAt: startedAt)

        await coordinator.workoutStarted(session, isNew: false)
        await coordinator.reconcile(activeSessions: [session])

        XCTAssertEqual(center.added.count, 2)
        XCTAssertEqual(
            center.added.map(\.identifier),
            WorkoutEndReminderNotification.identifiers(workoutID: session.id)
        )
        XCTAssertEqual(
            center.added.map(\.fireDate),
            [
                startedAt.addingTimeInterval(6 * 60 * 60),
                startedAt.addingTimeInterval(8 * 60 * 60),
            ]
        )
    }

    func testEndingWorkoutCancelsBothNotificationSlots() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let session = WorkoutSession(startedAt: Date(timeIntervalSince1970: 1_000))
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { session.startedAt }
        )
        await coordinator.workoutStarted(session, isNew: false)

        await coordinator.workoutEnded(session.id)

        let identifiers = Set(WorkoutEndReminderNotification.identifiers(workoutID: session.id))
        XCTAssertEqual(Set(center.removedPending), identifiers)
        XCTAssertEqual(Set(center.removedDelivered), identifiers)
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testDisablingNotificationsCancelsPendingAndReenableCanRestoreFutureSlots() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSession(startedAt: startedAt)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { startedAt }
        )
        await coordinator.workoutStarted(session, isNew: false)

        await coordinator.setNotificationsEnabled(false, activeSessions: [session])
        XCTAssertTrue(center.pending.isEmpty)

        await coordinator.setNotificationsEnabled(true, activeSessions: [session])
        XCTAssertEqual(center.added.count, 4)
        XCTAssertEqual(center.pending.count, 2)
    }

    func testDeniedNotificationPermissionDoesNotBlockWorkoutStart() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        center.status = .denied
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences
        )
        let container = try makeContainer()

        let session = try WorkoutSessionService(context: container.mainContext).startOrResume()
        await coordinator.workoutStarted(session, isNew: true)

        XCTAssertNil(session.endedAt)
        XCTAssertEqual(
            try WorkoutSessionService(context: container.mainContext).activeSession()?.id,
            session.id
        )
        XCTAssertTrue(center.added.isEmpty)
    }

    func testFirstWorkoutExplainsPermissionOnlyOnceBeforeRequest() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences
        )
        let session = WorkoutSession()

        await coordinator.workoutStarted(session, isNew: true)
        XCTAssertTrue(coordinator.isShowingPermissionExplanation)
        XCTAssertTrue(center.added.isEmpty)

        coordinator.skipNotificationPermission()
        await coordinator.workoutStarted(session, isNew: true)
        XCTAssertFalse(coordinator.isShowingPermissionExplanation)
    }

    func testDisablingWhileAddIsInFlightRemovesLateRequest() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSession(startedAt: startedAt)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { startedAt }
        )
        center.onAdd = {
            await coordinator.setNotificationsEnabled(false, activeSessions: [session])
        }

        await coordinator.workoutStarted(session, isNew: false)

        XCTAssertFalse(coordinator.notificationsEnabled)
        XCTAssertEqual(center.added.count, 1)
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testContinuingSuppressesSheetForTwoHoursAndMovesOnlyPendingFollowUp() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let clock = Clock(startedAt)
        let session = WorkoutSession(startedAt: startedAt)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { clock.now }
        )
        await coordinator.workoutStarted(session, isNew: false)
        let initialID = WorkoutEndReminderNotification.identifier(
            workoutID: session.id,
            slot: .initial
        )
        center.pending.remove(initialID)
        clock.now = startedAt.addingTimeInterval(6 * 60 * 60 + 30 * 60)

        await coordinator.continueWorkout(session)

        XCTAssertFalse(coordinator.shouldPresentReminder(for: session))
        XCTAssertEqual(center.added.count, 3)
        XCTAssertEqual(
            center.added.last?.fireDate,
            clock.now.addingTimeInterval(2 * 60 * 60)
        )
        clock.now = clock.now.addingTimeInterval(2 * 60 * 60)
        XCTAssertTrue(coordinator.shouldPresentReminder(for: session))
    }

    func testContinuingWithBothSlotsPendingKeepsOnlyFollowUpSlot() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let clock = Clock(startedAt)
        let session = WorkoutSession(startedAt: startedAt)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { clock.now }
        )
        await coordinator.workoutStarted(session, isNew: false)
        clock.now = startedAt.addingTimeInterval(6 * 60 * 60)

        await coordinator.continueWorkout(session)

        XCTAssertEqual(center.added.count, 3)
        XCTAssertEqual(
            center.added.last?.identifier,
            WorkoutEndReminderNotification.identifier(workoutID: session.id, slot: .followUp)
        )
        XCTAssertEqual(center.pending.count, 1)
    }

    func testReconcileDoesNotRegisterPastNotificationSlots() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let clock = Clock(startedAt.addingTimeInterval(9 * 60 * 60))
        let session = WorkoutSession(startedAt: startedAt)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { clock.now }
        )

        await coordinator.reconcile(activeSessions: [session])
        await coordinator.reconcile(activeSessions: [session])

        XCTAssertTrue(center.added.isEmpty)
    }

    func testEndDateValidationRejectsBeforeStartAndFuture() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        XCTAssertNotNil(
            WorkoutEndDateValidation.message(
                startedAt: startedAt,
                endedAt: Date(timeIntervalSince1970: 999),
                latestAllowedDate: now
            )
        )
        XCTAssertNotNil(
            WorkoutEndDateValidation.message(
                startedAt: startedAt,
                endedAt: Date(timeIntervalSince1970: 2_001),
                latestAllowedDate: now
            )
        )
        XCTAssertNil(
            WorkoutEndDateValidation.message(
                startedAt: startedAt,
                endedAt: now,
                latestAllowedDate: now
            )
        )
    }

    func testSpecifiedEndDateUsesExistingFinishCleanupAndSummary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 10_000)
        let requestedEnd = Date(timeIntervalSince1970: 5_000)
        let session = WorkoutSession(startedAt: startedAt)
        let savedEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "保存済み", primaryBodyPart: .other),
            order: 3
        )
        let emptyEntry = ExerciseEntry(
            workoutSession: session,
            exercise: Exercise(name: "空", primaryBodyPart: .other),
            order: 4
        )
        context.insert(savedEntry)
        context.insert(emptyEntry)
        context.insert(SetEntry(exerciseEntry: savedEntry, order: 0, weightKg: 20, reps: 10))
        try context.save()

        let summary = try WorkoutSessionService(context: context, now: { now }).finish(
            session,
            endedAt: requestedEnd
        )

        XCTAssertEqual(session.endedAt, requestedEnd)
        XCTAssertEqual(summary.duration, 4_000)
        XCTAssertEqual(summary.exerciseCount, 1)
        XCTAssertEqual(summary.setCount, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseEntry>()).map(\.id), [savedEntry.id])
        XCTAssertEqual(savedEntry.order, 0)
    }

    func testSpecifiedEndDateFailureAndEmptyWorkoutDoNotCompleteSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSession(startedAt: startedAt)
        context.insert(session)
        try context.save()
        let service = WorkoutSessionService(
            context: context,
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        XCTAssertThrowsError(
            try service.finish(session, endedAt: Date(timeIntervalSince1970: 999))
        ) { error in
            XCTAssertEqual(error as? WorkoutSessionError, .invalidEndDate)
        }
        XCTAssertThrowsError(
            try service.finish(session, endedAt: Date(timeIntervalSince1970: 2_001))
        ) { error in
            XCTAssertEqual(error as? WorkoutSessionError, .invalidEndDate)
        }
        XCTAssertThrowsError(
            try service.finish(session, endedAt: Date(timeIntervalSince1970: 1_500))
        ) { error in
            XCTAssertEqual(error as? WorkoutSessionError, .noSavedSets)
        }
        XCTAssertNil(session.endedAt)
    }

    func testCompletedWorkoutNeverQualifiesForTappedReminderSheet() throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 30_000)
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 2_000)
        )
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: FakeNotificationCenter(),
            preferences: preferences,
            now: { now }
        )

        XCTAssertFalse(coordinator.shouldPresentReminder(for: session))
    }
}

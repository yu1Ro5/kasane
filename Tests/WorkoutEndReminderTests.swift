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
        var requestAuthorizationCount = 0
        var added: [AddedReminder] = []
        var pending: Set<String> = []
        var removedPending: [String] = []
        var removedDelivered: [String] = []
        var onPending: (() -> Void)?
        var onAdd: (() async -> Void)?

        func authorizationStatus() async -> WorkoutEndReminderAuthorizationStatus { status }

        func requestAuthorization() async throws -> Bool {
            requestAuthorizationCount += 1
            status = requestAuthorizationResult ? .authorized : .denied
            return requestAuthorizationResult
        }

        func pendingRequestIdentifiers() async -> Set<String> {
            onPending?()
            onPending = nil
            return pending
        }

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

    func testThreeHourSchedulingBoundary() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSession(startedAt: startedAt)
        let deadline = startedAt.addingTimeInterval(3 * 60 * 60)

        XCTAssertEqual(WorkoutEndReminderPolicy.notificationDate(for: session), deadline)
        XCTAssertTrue(
            WorkoutEndReminderPolicy.canSchedule(
                session,
                at: deadline.addingTimeInterval(-1)
            )
        )
        XCTAssertFalse(WorkoutEndReminderPolicy.canSchedule(session, at: deadline))
        XCTAssertFalse(
            WorkoutEndReminderPolicy.canSchedule(
                session,
                at: deadline.addingTimeInterval(1)
            )
        )
    }

    func testSchedulesOneReminderAtThreeHoursWithoutDuplicatesAcrossRestart() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSession(startedAt: startedAt)
        let makeCoordinator = {
            WorkoutEndReminderCoordinator(
                notificationCenter: center,
                preferences: preferences,
                now: { startedAt }
            )
        }

        let firstCoordinator = makeCoordinator()
        await firstCoordinator.workoutStarted(session)
        await firstCoordinator.workoutStarted(session)
        await makeCoordinator().workoutStarted(session)

        XCTAssertEqual(center.added.count, 1)
        XCTAssertEqual(
            center.added.first,
            .init(
                identifier: WorkoutEndReminderNotification.identifier(workoutID: session.id),
                workoutID: session.id,
                fireDate: startedAt.addingTimeInterval(3 * 60 * 60)
            )
        )
    }

    func testDeliveredReminderIsNotRegisteredAgainAfterDeadline() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let clock = Clock(startedAt)
        let session = WorkoutSession(startedAt: startedAt)
        let makeCoordinator = {
            WorkoutEndReminderCoordinator(
                notificationCenter: center,
                preferences: preferences,
                now: { clock.now }
            )
        }

        await makeCoordinator().workoutStarted(session)
        center.pending.removeAll()
        clock.now = WorkoutEndReminderPolicy.notificationDate(for: session)
        await makeCoordinator().workoutStarted(session)

        XCTAssertEqual(center.added.count, 1)
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testDoesNotScheduleWhenDeadlinePassesDuringPendingRequestCheck() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let deadline = startedAt.addingTimeInterval(3 * 60 * 60)
        let clock = Clock(deadline.addingTimeInterval(-1))
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { clock.now }
        )
        center.onPending = { clock.now = deadline }

        await coordinator.workoutStarted(WorkoutSession(startedAt: startedAt))

        XCTAssertTrue(center.added.isEmpty)
    }

    func testEndingOrDiscardingRemovesOnlyThatWorkoutReminder() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences
        )
        let workoutID = UUID()
        let otherID = WorkoutEndReminderNotification.identifier(workoutID: UUID())
        let identifier = WorkoutEndReminderNotification.identifier(workoutID: workoutID)
        center.pending = [identifier, otherID]

        coordinator.cancelReminder(workoutID: workoutID)

        XCTAssertEqual(center.removedPending, [identifier])
        XCTAssertEqual(center.removedDelivered, [identifier])
        XCTAssertEqual(center.pending, [otherID])
    }

    func testCancellationWinsWhenSchedulingIsInFlight() async throws {
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
            coordinator.cancelReminder(workoutID: session.id)
        }

        await coordinator.workoutStarted(session)

        XCTAssertTrue(center.pending.isEmpty)
    }

    func testDeniedPermissionDoesNotBlockWorkoutLifecycle() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        center.status = .denied
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences
        )
        let container = try makeContainer()
        let service = WorkoutSessionService(context: container.mainContext)

        let session = try service.startOrResume()
        await coordinator.workoutStarted(session)
        try service.discard(session)
        coordinator.cancelReminder(workoutID: session.id)

        XCTAssertTrue(center.added.isEmpty)
        XCTAssertNil(try service.activeSession())
    }

    func testPermissionExplanationIsNotRepeatedAfterSkipping() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        let session = WorkoutSession()
        let firstCoordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences
        )

        await firstCoordinator.workoutStarted(session)
        XCTAssertTrue(firstCoordinator.isShowingPermissionExplanation)
        firstCoordinator.skipNotificationPermission()

        let restartedCoordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences
        )
        await restartedCoordinator.workoutStarted(session)
        XCTAssertFalse(restartedCoordinator.isShowingPermissionExplanation)
        XCTAssertEqual(center.requestAuthorizationCount, 0)
        XCTAssertTrue(center.added.isEmpty)
    }

    func testAllowingPermissionSchedulesCurrentWorkoutOnce() async throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let session = WorkoutSession(startedAt: startedAt)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: center,
            preferences: preferences,
            now: { startedAt }
        )

        await coordinator.workoutStarted(session)
        await coordinator.allowNotifications(for: session)

        XCTAssertEqual(center.requestAuthorizationCount, 1)
        XCTAssertEqual(center.added.count, 1)
    }

    func testNotificationTapIsPersistedAndConsumedOnlyOnce() throws {
        let (preferences, suiteName) = try makePreferences()
        defer { preferences.defaults.removePersistentDomain(forName: suiteName) }
        let workoutID = UUID()
        preferences.savePendingTappedWorkoutID(workoutID)
        let coordinator = WorkoutEndReminderCoordinator(
            notificationCenter: FakeNotificationCenter(),
            preferences: preferences
        )

        XCTAssertEqual(coordinator.consumeNotificationTap(), workoutID)
        XCTAssertNil(coordinator.consumeNotificationTap())
    }
}

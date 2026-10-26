import Foundation
import Observation
import UserNotifications

enum WorkoutEndReminderPolicy {
    static let delay: TimeInterval = 3 * 60 * 60

    static func notificationDate(for session: WorkoutSession) -> Date {
        session.startedAt.addingTimeInterval(delay)
    }

    static func canSchedule(_ session: WorkoutSession, at date: Date) -> Bool {
        session.endedAt == nil && notificationDate(for: session) > date
    }
}

enum WorkoutEndReminderAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
}

@MainActor
protocol WorkoutEndReminderNotificationCenter: AnyObject {
    func authorizationStatus() async -> WorkoutEndReminderAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func pendingRequestIdentifiers() async -> Set<String>
    func addReminder(identifier: String, workoutID: UUID, fireDate: Date) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemWorkoutEndReminderNotificationCenter: WorkoutEndReminderNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> WorkoutEndReminderAuthorizationStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            .authorized
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingRequestIdentifiers() async -> Set<String> {
        Set(await center.pendingNotificationRequests().map(\.identifier))
    }

    func addReminder(identifier: String, workoutID: UUID, fireDate: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "ワークアウトを終了し忘れていませんか？"
        content.body = "KASANEを開いて、ワークアウトの記録を確認しましょう。"
        content.sound = .default
        content.userInfo = [WorkoutEndReminderNotification.workoutIDKey: workoutID.uuidString]
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try await center.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor
final class DisabledWorkoutEndReminderNotificationCenter: WorkoutEndReminderNotificationCenter {
    func authorizationStatus() async -> WorkoutEndReminderAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func pendingRequestIdentifiers() async -> Set<String> { [] }
    func addReminder(identifier: String, workoutID: UUID, fireDate: Date) async throws {}
    func removePendingRequests(withIdentifiers identifiers: [String]) {}
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}

enum WorkoutEndReminderNotification {
    static let identifierPrefix = "workout-end-reminder."
    static let workoutIDKey = "workoutID"

    static func identifier(workoutID: UUID) -> String {
        identifierPrefix + workoutID.uuidString
    }
}

struct WorkoutEndReminderPreferences {
    private enum Key {
        static let permissionExplanationShown = "workoutEndReminder.permissionExplanationShown"
        static let pendingTappedWorkoutID = "workoutEndReminder.pendingTappedWorkoutID"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var permissionExplanationShown: Bool {
        get { defaults.bool(forKey: Key.permissionExplanationShown) }
        nonmutating set { defaults.set(newValue, forKey: Key.permissionExplanationShown) }
    }

    func savePendingTappedWorkoutID(_ workoutID: UUID) {
        defaults.set(workoutID.uuidString, forKey: Key.pendingTappedWorkoutID)
    }

    func consumePendingTappedWorkoutID() -> UUID? {
        defer { defaults.removeObject(forKey: Key.pendingTappedWorkoutID) }
        guard let value = defaults.string(forKey: Key.pendingTappedWorkoutID) else { return nil }
        return UUID(uuidString: value)
    }
}

@MainActor
@Observable
final class WorkoutEndReminderCoordinator {
    private let notificationCenter: any WorkoutEndReminderNotificationCenter
    private let preferences: WorkoutEndReminderPreferences
    private let now: () -> Date
    private let presentsPermissionExplanation: Bool
    private var workoutRevisions: [UUID: Int] = [:]

    private(set) var authorizationStatus: WorkoutEndReminderAuthorizationStatus = .notDetermined
    var isShowingPermissionExplanation = false
    var notificationErrorMessage: String?

    init(
        notificationCenter: any WorkoutEndReminderNotificationCenter,
        preferences: WorkoutEndReminderPreferences = WorkoutEndReminderPreferences(),
        now: @escaping () -> Date = Date.init,
        presentsPermissionExplanation: Bool = true
    ) {
        self.notificationCenter = notificationCenter
        self.preferences = preferences
        self.now = now
        self.presentsPermissionExplanation = presentsPermissionExplanation
    }

    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> WorkoutEndReminderCoordinator {
        let isUITesting = arguments.contains("--ui-testing")
        let notificationCenter: any WorkoutEndReminderNotificationCenter =
            isUITesting
            ? DisabledWorkoutEndReminderNotificationCenter()
            : SystemWorkoutEndReminderNotificationCenter()
        return WorkoutEndReminderCoordinator(
            notificationCenter: notificationCenter,
            presentsPermissionExplanation: !isUITesting
        )
    }

    var notificationStatusText: String {
        switch authorizationStatus {
        case .authorized: "許可済み"
        case .denied: "iPhoneの設定で通知がオフ"
        case .notDetermined: "未設定"
        }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await notificationCenter.authorizationStatus()
    }

    func workoutStarted(_ session: WorkoutSession) async {
        await refreshAuthorizationStatus()
        if !preferences.permissionExplanationShown,
            authorizationStatus == .notDetermined,
            presentsPermissionExplanation
        {
            isShowingPermissionExplanation = true
            return
        }
        await scheduleIfNeeded(for: session)
    }

    func allowNotifications(for session: WorkoutSession?) async {
        preferences.permissionExplanationShown = true
        isShowingPermissionExplanation = false
        do {
            _ = try await notificationCenter.requestAuthorization()
            await refreshAuthorizationStatus()
            if let session {
                await scheduleIfNeeded(for: session)
            }
        } catch {
            notificationErrorMessage = error.localizedDescription
            await refreshAuthorizationStatus()
        }
    }

    func skipNotificationPermission() {
        preferences.permissionExplanationShown = true
        isShowingPermissionExplanation = false
    }

    func cancelReminder(workoutID: UUID) {
        workoutRevisions[workoutID, default: 0] += 1
        let identifier = WorkoutEndReminderNotification.identifier(workoutID: workoutID)
        notificationCenter.removePendingRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    @discardableResult
    func consumeNotificationTap() -> UUID? {
        preferences.consumePendingTappedWorkoutID()
    }

    private func scheduleIfNeeded(for session: WorkoutSession) async {
        guard authorizationStatus == .authorized else { return }

        let identifier = WorkoutEndReminderNotification.identifier(workoutID: session.id)
        let revision = workoutRevisions[session.id, default: 0]
        let pending = await notificationCenter.pendingRequestIdentifiers()
        guard workoutRevisions[session.id, default: 0] == revision else { return }
        guard !pending.contains(identifier) else { return }
        guard WorkoutEndReminderPolicy.canSchedule(session, at: now()) else { return }

        do {
            try await notificationCenter.addReminder(
                identifier: identifier,
                workoutID: session.id,
                fireDate: WorkoutEndReminderPolicy.notificationDate(for: session)
            )
            guard workoutRevisions[session.id, default: 0] == revision else {
                notificationCenter.removePendingRequests(withIdentifiers: [identifier])
                return
            }
        } catch {
            notificationErrorMessage = error.localizedDescription
        }
    }
}

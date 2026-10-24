import Foundation
import Observation
import UserNotifications

enum WorkoutEndReminderPolicy {
    static let initialDelay: TimeInterval = 6 * 60 * 60
    static let followUpDelay: TimeInterval = 8 * 60 * 60
    static let continuationSuppression: TimeInterval = 2 * 60 * 60

    static func isOverdue(
        _ session: WorkoutSession,
        at date: Date,
        suppressedUntil: Date? = nil
    ) -> Bool {
        guard session.endedAt == nil else { return false }
        guard date.timeIntervalSince(session.startedAt) >= initialDelay else { return false }
        return suppressedUntil.map { date >= $0 } ?? true
    }
}

enum WorkoutEndDateValidation {
    static func message(startedAt: Date, endedAt: Date, latestAllowedDate: Date?) -> String? {
        if endedAt < startedAt {
            return "終了日時は開始日時以降にしてください。"
        }
        if let latestAllowedDate, endedAt > latestAllowedDate {
            return "未来の日時を終了日時には指定できません。"
        }
        return nil
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
        content.body = "記録を確認して、終了するか続けるか選択できます。"
        content.sound = .default
        content.userInfo = [WorkoutEndReminderNotification.workoutIDKey: workoutID.uuidString]
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
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

    enum Slot: String, CaseIterable {
        case initial
        case followUp = "follow-up"

        var delay: TimeInterval {
            switch self {
            case .initial: WorkoutEndReminderPolicy.initialDelay
            case .followUp: WorkoutEndReminderPolicy.followUpDelay
            }
        }
    }

    static func identifier(workoutID: UUID, slot: Slot) -> String {
        "\(identifierPrefix)\(workoutID.uuidString).\(slot.rawValue)"
    }

    static func identifiers(workoutID: UUID) -> [String] {
        Slot.allCases.map { identifier(workoutID: workoutID, slot: $0) }
    }

    static func workoutID(from identifier: String) -> UUID? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        let remainder = identifier.dropFirst(identifierPrefix.count)
        guard let separator = remainder.lastIndex(of: ".") else { return nil }
        return UUID(uuidString: String(remainder[..<separator]))
    }
}

struct WorkoutEndReminderPreferences {
    private enum Key {
        static let notificationsEnabled = "workoutEndReminder.notificationsEnabled"
        static let permissionExplanationShown = "workoutEndReminder.permissionExplanationShown"
        static let pendingTappedWorkoutID = "workoutEndReminder.pendingTappedWorkoutID"
        static let registeredPrefix = "workoutEndReminder.registered."
        static let suppressionPrefix = "workoutEndReminder.suppressedUntil."
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var notificationsEnabled: Bool {
        get {
            guard defaults.object(forKey: Key.notificationsEnabled) != nil else { return true }
            return defaults.bool(forKey: Key.notificationsEnabled)
        }
        nonmutating set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    var permissionExplanationShown: Bool {
        get { defaults.bool(forKey: Key.permissionExplanationShown) }
        nonmutating set { defaults.set(newValue, forKey: Key.permissionExplanationShown) }
    }

    func isRegistered(workoutID: UUID, slot: WorkoutEndReminderNotification.Slot) -> Bool {
        defaults.bool(forKey: registeredKey(workoutID: workoutID, slot: slot))
    }

    func setRegistered(
        _ registered: Bool,
        workoutID: UUID,
        slot: WorkoutEndReminderNotification.Slot
    ) {
        defaults.set(registered, forKey: registeredKey(workoutID: workoutID, slot: slot))
    }

    func suppressionDate(workoutID: UUID) -> Date? {
        let key = Key.suppressionPrefix + workoutID.uuidString
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    func setSuppressionDate(_ date: Date?, workoutID: UUID) {
        let key = Key.suppressionPrefix + workoutID.uuidString
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func clearControlState(workoutID: UUID) {
        for slot in WorkoutEndReminderNotification.Slot.allCases {
            defaults.removeObject(forKey: registeredKey(workoutID: workoutID, slot: slot))
        }
        setSuppressionDate(nil, workoutID: workoutID)
    }

    func savePendingTappedWorkoutID(_ workoutID: UUID) {
        defaults.set(workoutID.uuidString, forKey: Key.pendingTappedWorkoutID)
    }

    func consumePendingTappedWorkoutID() -> UUID? {
        defer { defaults.removeObject(forKey: Key.pendingTappedWorkoutID) }
        guard let value = defaults.string(forKey: Key.pendingTappedWorkoutID) else { return nil }
        return UUID(uuidString: value)
    }

    private func registeredKey(
        workoutID: UUID,
        slot: WorkoutEndReminderNotification.Slot
    ) -> String {
        Key.registeredPrefix
            + WorkoutEndReminderNotification.identifier(workoutID: workoutID, slot: slot)
    }
}

@MainActor
@Observable
final class WorkoutEndReminderCoordinator {
    private let notificationCenter: any WorkoutEndReminderNotificationCenter
    private let preferences: WorkoutEndReminderPreferences
    private let now: () -> Date
    private let automaticallyPresentsInAppReminder: Bool
    private let presentsPermissionExplanation: Bool
    private var configurationRevision = 0
    private var workoutRevisions: [UUID: Int] = [:]

    private(set) var authorizationStatus: WorkoutEndReminderAuthorizationStatus = .notDetermined
    private(set) var notificationsEnabled: Bool
    private(set) var presentedWorkoutID: UUID?
    private(set) var tappedWorkoutID: UUID?
    private(set) var checkGeneration = 0
    var isShowingPermissionExplanation = false
    var notificationErrorMessage: String?

    init(
        notificationCenter: any WorkoutEndReminderNotificationCenter,
        preferences: WorkoutEndReminderPreferences = WorkoutEndReminderPreferences(),
        now: @escaping () -> Date = Date.init,
        automaticallyPresentsInAppReminder: Bool = true,
        presentsPermissionExplanation: Bool = true
    ) {
        self.notificationCenter = notificationCenter
        self.preferences = preferences
        self.now = now
        self.automaticallyPresentsInAppReminder = automaticallyPresentsInAppReminder
        self.presentsPermissionExplanation = presentsPermissionExplanation
        notificationsEnabled = preferences.notificationsEnabled
    }

    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> WorkoutEndReminderCoordinator {
        let isUITesting = arguments.contains("--ui-testing")
        let notificationCenter: any WorkoutEndReminderNotificationCenter =
            isUITesting
            ? DisabledWorkoutEndReminderNotificationCenter()
            : SystemWorkoutEndReminderNotificationCenter()
        return WorkoutEndReminderCoordinator(
            notificationCenter: notificationCenter,
            automaticallyPresentsInAppReminder: !isUITesting
                || arguments.contains("--workout-reminder-fixture"),
            presentsPermissionExplanation: !isUITesting
        )
    }

    var notificationStatusText: String {
        guard notificationsEnabled else { return "オフ" }
        switch authorizationStatus {
        case .authorized: return "許可済み"
        case .denied: return "iPhoneの設定で通知がオフ"
        case .notDetermined: return "未設定"
        }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await notificationCenter.authorizationStatus()
    }

    func workoutStarted(_ session: WorkoutSession, isNew: Bool) async {
        await refreshAuthorizationStatus()
        if isNew, notificationsEnabled, !preferences.permissionExplanationShown,
            authorizationStatus == .notDetermined, presentsPermissionExplanation
        {
            isShowingPermissionExplanation = true
            return
        }
        await scheduleIfNeeded(for: session)
    }

    func allowNotifications(for sessions: [WorkoutSession]) async {
        preferences.permissionExplanationShown = true
        isShowingPermissionExplanation = false
        do {
            _ = try await notificationCenter.requestAuthorization()
            await refreshAuthorizationStatus()
            for session in sessions {
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

    func setNotificationsEnabled(_ enabled: Bool, activeSessions: [WorkoutSession]) async {
        configurationRevision += 1
        notificationsEnabled = enabled
        preferences.notificationsEnabled = enabled
        if !enabled {
            await cancelAllPendingReminders(clearPendingRegistration: true)
            return
        }

        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            preferences.permissionExplanationShown = true
            do {
                _ = try await notificationCenter.requestAuthorization()
            } catch {
                notificationErrorMessage = error.localizedDescription
            }
            await refreshAuthorizationStatus()
        }
        for session in activeSessions {
            await scheduleIfNeeded(for: session)
        }
    }

    func reconcile(activeSessions: [WorkoutSession]) async {
        await refreshAuthorizationStatus()
        let activeIDs = Set(activeSessions.filter { $0.endedAt == nil }.map(\.id))
        let pending = await notificationCenter.pendingRequestIdentifiers()
        let orphaned = pending.filter { identifier in
            guard let workoutID = WorkoutEndReminderNotification.workoutID(from: identifier) else {
                return false
            }
            return !activeIDs.contains(workoutID)
        }
        if !orphaned.isEmpty {
            notificationCenter.removePendingRequests(withIdentifiers: Array(orphaned))
        }

        guard notificationsEnabled else {
            await cancelAllPendingReminders(clearPendingRegistration: true)
            return
        }
        for session in activeSessions where session.endedAt == nil {
            await scheduleIfNeeded(for: session)
        }
    }

    func continueWorkout(_ session: WorkoutSession) async {
        presentedWorkoutID = nil
        workoutRevisions[session.id, default: 0] += 1
        let suppressionDate = now().addingTimeInterval(WorkoutEndReminderPolicy.continuationSuppression)
        preferences.setSuppressionDate(suppressionDate, workoutID: session.id)

        let pending = await notificationCenter.pendingRequestIdentifiers()
        let sessionIdentifiers = Set(
            WorkoutEndReminderNotification.identifiers(workoutID: session.id)
        )
        let matching = pending.intersection(sessionIdentifiers)
        notificationCenter.removePendingRequests(withIdentifiers: Array(matching))
        let latestPendingSlot = WorkoutEndReminderNotification.Slot.allCases
            .filter {
                matching.contains(
                    WorkoutEndReminderNotification.identifier(workoutID: session.id, slot: $0)
                )
            }
            .max { $0.delay < $1.delay }
        for slot in WorkoutEndReminderNotification.Slot.allCases {
            let identifier = WorkoutEndReminderNotification.identifier(
                workoutID: session.id,
                slot: slot
            )
            if matching.contains(identifier) {
                // 2件とも未配信でも、続行後は遅い方の1枠だけを残して同時通知を避ける。
                preferences.setRegistered(
                    slot != latestPendingSlot,
                    workoutID: session.id,
                    slot: slot
                )
            }
        }
        await scheduleIfNeeded(for: session)
    }

    func workoutEnded(_ workoutID: UUID) async {
        workoutRevisions[workoutID, default: 0] += 1
        dismissReminder(for: workoutID)
        let identifiers = WorkoutEndReminderNotification.identifiers(workoutID: workoutID)
        notificationCenter.removePendingRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        preferences.clearControlState(workoutID: workoutID)
    }

    func shouldPresentReminder(for session: WorkoutSession) -> Bool {
        automaticallyPresentsInAppReminder
            && WorkoutEndReminderPolicy.isOverdue(
                session,
                at: now(),
                suppressedUntil: preferences.suppressionDate(workoutID: session.id)
            )
    }

    func presentReminder(for workoutID: UUID) {
        presentedWorkoutID = workoutID
    }

    func dismissReminder(for workoutID: UUID) {
        if presentedWorkoutID == workoutID {
            presentedWorkoutID = nil
        }
    }

    func requestCheck() {
        checkGeneration += 1
    }

    @discardableResult
    func consumeNotificationTap() -> Bool {
        guard let workoutID = preferences.consumePendingTappedWorkoutID() else { return false }
        tappedWorkoutID = workoutID
        requestCheck()
        return true
    }

    func takeTappedWorkoutID() -> UUID? {
        defer { tappedWorkoutID = nil }
        return tappedWorkoutID
    }

    private func scheduleIfNeeded(for session: WorkoutSession) async {
        guard session.endedAt == nil, notificationsEnabled else { return }
        guard authorizationStatus == .authorized else { return }

        let capturedConfigurationRevision = configurationRevision
        let capturedWorkoutRevision = workoutRevisions[session.id, default: 0]
        let currentDate = now()
        let pending = await notificationCenter.pendingRequestIdentifiers()
        guard
            schedulingIsCurrent(
                workoutID: session.id,
                configurationRevision: capturedConfigurationRevision,
                workoutRevision: capturedWorkoutRevision
            )
        else { return }
        let suppressedUntil = preferences.suppressionDate(workoutID: session.id)
        for slot in WorkoutEndReminderNotification.Slot.allCases {
            guard
                schedulingIsCurrent(
                    workoutID: session.id,
                    configurationRevision: capturedConfigurationRevision,
                    workoutRevision: capturedWorkoutRevision
                )
            else { return }
            let identifier = WorkoutEndReminderNotification.identifier(
                workoutID: session.id,
                slot: slot
            )
            if pending.contains(identifier) {
                preferences.setRegistered(true, workoutID: session.id, slot: slot)
                continue
            }
            guard !preferences.isRegistered(workoutID: session.id, slot: slot) else { continue }

            let originalDate = session.startedAt.addingTimeInterval(slot.delay)
            let fireDate = max(originalDate, suppressedUntil ?? originalDate)
            guard fireDate > currentDate else {
                // 過去分は配信済みか判別できないため、再登録せず消費済みとして扱う。
                preferences.setRegistered(true, workoutID: session.id, slot: slot)
                continue
            }
            do {
                try await notificationCenter.addReminder(
                    identifier: identifier,
                    workoutID: session.id,
                    fireDate: fireDate
                )
                guard
                    schedulingIsCurrent(
                        workoutID: session.id,
                        configurationRevision: capturedConfigurationRevision,
                        workoutRevision: capturedWorkoutRevision
                    )
                else {
                    notificationCenter.removePendingRequests(withIdentifiers: [identifier])
                    continue
                }
                preferences.setRegistered(true, workoutID: session.id, slot: slot)
            } catch {
                notificationErrorMessage = error.localizedDescription
            }
        }
    }

    private func schedulingIsCurrent(
        workoutID: UUID,
        configurationRevision: Int,
        workoutRevision: Int
    ) -> Bool {
        notificationsEnabled
            && self.configurationRevision == configurationRevision
            && workoutRevisions[workoutID, default: 0] == workoutRevision
    }

    private func cancelAllPendingReminders(clearPendingRegistration: Bool) async {
        let pending = await notificationCenter.pendingRequestIdentifiers()
        let reminderIdentifiers = pending.filter {
            $0.hasPrefix(WorkoutEndReminderNotification.identifierPrefix)
        }
        notificationCenter.removePendingRequests(withIdentifiers: Array(reminderIdentifiers))
        guard clearPendingRegistration else { return }
        for identifier in reminderIdentifiers {
            guard let workoutID = WorkoutEndReminderNotification.workoutID(from: identifier) else {
                continue
            }
            for slot in WorkoutEndReminderNotification.Slot.allCases
            where WorkoutEndReminderNotification.identifier(workoutID: workoutID, slot: slot)
                == identifier
            {
                preferences.setRegistered(false, workoutID: workoutID, slot: slot)
            }
        }
    }
}

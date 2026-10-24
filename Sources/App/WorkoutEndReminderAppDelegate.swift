import UIKit
import UserNotifications

extension Notification.Name {
    static let workoutEndReminderTapped = Notification.Name("workoutEndReminderTapped")
}

final class WorkoutEndReminderAppDelegate: NSObject, UIApplicationDelegate,
    UNUserNotificationCenterDelegate
{
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard
            let value = response.notification.request.content.userInfo[
                WorkoutEndReminderNotification.workoutIDKey
            ] as? String,
            let workoutID = UUID(uuidString: value)
        else { return }

        WorkoutEndReminderPreferences().savePendingTappedWorkoutID(workoutID)
        await MainActor.run {
            NotificationCenter.default.post(name: .workoutEndReminderTapped, object: nil)
        }
    }
}

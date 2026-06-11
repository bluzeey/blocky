import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    func setupDelegate() {
        UNUserNotificationCenter.current().delegate = self
        Logger.log("Notifications", "Set UNUserNotificationCenter delegate")
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func send(title: String, body: String) async {
        Logger.log("Notifications", "Sending local notification title=\(title) body=\(body)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.log("Notifications", "Failed to send local notification: \(error.localizedDescription)")
        }
    }
}

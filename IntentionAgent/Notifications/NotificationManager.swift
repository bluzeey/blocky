import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    func send(title: String, body: String) async {
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

import AppKit
import ApplicationServices
import Foundation
import UserNotifications

struct PermissionSnapshot: Equatable {
    var accessibilityGranted: Bool
    var screenRecordingGranted: Bool
    var notificationsGranted: Bool

    static let empty = PermissionSnapshot(
        accessibilityGranted: false,
        screenRecordingGranted: false,
        notificationsGranted: false
    )
}

@MainActor
final class PermissionManager {
    func refreshSnapshot() async -> PermissionSnapshot {
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        let snapshot = PermissionSnapshot(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess(),
            notificationsGranted: notificationSettings.authorizationStatus == .authorized
        )
        Logger.log("Permissions", "Snapshot refreshed: accessibility=\(snapshot.accessibilityGranted) screenRecording=\(snapshot.screenRecordingGranted) notifications=\(snapshot.notificationsGranted)")
        return snapshot
    }

    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        Logger.log("Permissions", "Requested accessibility permission. immediateGranted=\(granted)")
        return granted
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        Logger.log("Permissions", "Requested screen recording permission. immediateGranted=\(granted)")
        return granted
    }

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            Logger.log("Permissions", "Requested notification permission. granted=\(granted)")
            return granted
        } catch {
            Logger.log("Permissions", "Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        Logger.log("Permissions", "Opening Accessibility settings")
        NSWorkspace.shared.open(url)
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        Logger.log("Permissions", "Opening Screen Recording settings")
        NSWorkspace.shared.open(url)
    }

    func openNotificationsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        Logger.log("Permissions", "Opening Notifications settings")
        NSWorkspace.shared.open(url)
    }
}

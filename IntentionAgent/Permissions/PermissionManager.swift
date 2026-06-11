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
        return PermissionSnapshot(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess(),
            notificationsGranted: notificationSettings.authorizationStatus == .authorized
        )
    }

    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            Logger.log("Permissions", "Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func openNotificationsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
}

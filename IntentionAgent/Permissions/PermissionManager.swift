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
        if !granted {
            openAccessibilitySettings()
            Logger.log("Permissions", "Requested accessibility permission, also opened System Settings")
        } else {
            Logger.log("Permissions", "Requested accessibility permission. immediateGranted=\(granted)")
        }
        return granted
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        let currentlyGranted = CGPreflightScreenCaptureAccess()
        if currentlyGranted {
            Logger.log("Permissions", "Screen recording already granted")
            return true
        }
        openScreenRecordingSettings()
        Logger.log("Permissions", "Opened Screen Recording settings (CGRequestScreenCaptureAccess deprecated on macOS 26)")
        return false
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

    func pollAccessibility(timeout: TimeInterval = 30) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if AXIsProcessTrusted() {
                Logger.log("Permissions", "Accessibility granted during poll")
                return true
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        Logger.log("Permissions", "Accessibility poll timed out")
        return AXIsProcessTrusted()
    }

    func pollScreenRecording(timeout: TimeInterval = 30) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if CGPreflightScreenCaptureAccess() {
                Logger.log("Permissions", "Screen recording granted during poll")
                return true
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        Logger.log("Permissions", "Screen recording poll timed out")
        return CGPreflightScreenCaptureAccess()
    }
}

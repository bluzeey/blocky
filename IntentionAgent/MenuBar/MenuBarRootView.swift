import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            permissionSection
            sessionSection
            contextSection
            actionsSection
        }
        .padding(16)
        .frame(width: 380)
        .task {
            await appState.startIfNeeded()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appState.activeSession?.title ?? "No active intention")
                .font(.headline)
            Text(appState.activeSession.map(appState.sessionManager.remainingTimeText(for:)) ?? "Start a session below")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.headline)

            PermissionRow(label: "Accessibility", granted: appState.permissionSnapshot.accessibilityGranted) {
                appState.requestAccessibilityPermission()
            }
            PermissionRow(label: "Screen Recording", granted: appState.permissionSnapshot.screenRecordingGranted) {
                appState.requestScreenRecordingPermission()
            }
            PermissionRow(label: "Notifications", granted: appState.permissionSnapshot.notificationsGranted) {
                Task {
                    await appState.requestNotificationPermission()
                }
            }
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Intention")
                .font(.headline)

            TextField("I want to watch YouTube for 30 minutes", text: $appState.sessionDraft.title)
            Stepper(value: $appState.sessionDraft.durationMinutes, in: 5...240, step: 5) {
                Text("Duration: \(appState.sessionDraft.durationMinutes) minutes")
            }
            TextField("Allowed apps (comma separated)", text: $appState.sessionDraft.allowedAppsText)
            TextField("Blocked apps (comma separated)", text: $appState.sessionDraft.blockedAppsText)

            HStack {
                Button(appState.activeSession == nil ? "Start Session" : "Switch Intention") {
                    appState.startSessionFromDraft()
                }
                .pointerCursor()

                Button(appState.activeSession?.isPaused == true ? "Resume" : "Pause") {
                    appState.togglePauseSession()
                }
                .disabled(appState.activeSession == nil)
                .pointerCursor()

                Button("End") {
                    appState.endSession()
                }
                .disabled(appState.activeSession == nil)
                .pointerCursor()
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Context")
                .font(.headline)

            Text(appState.currentMetadata.map { "\($0.activeAppName) - \($0.windowTitle ?? "Unknown Window")" } ?? "No active context yet")
            Text("Alignment: \(appState.currentAlignment.rawValue)")
                .foregroundStyle(color(for: appState.currentAlignment))
            Text(appState.currentDecision?.reason ?? "No privacy decision yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(appState.aiStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(appState.latestNudgeMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionsSection: some View {
        HStack {
            Button("Allow 5 Min") {
                appState.allowDriftForFiveMinutes()
            }
            .disabled(appState.activeSession == nil)
            .pointerCursor()

            Button("Capture Library") {
                openWindow(id: "capture-library")
            }
            .pointerCursor()

            Button("Settings") {
                openWindow(id: "settings")
            }
            .pointerCursor()
        }
    }

    private func color(for alignment: Alignment) -> Color {
        switch alignment {
        case .aligned:
            return .green
        case .drift:
            return .red
        case .sensitive:
            return .orange
        case .neutral, .unknown:
            return .yellow
        }
    }
}

private struct PermissionRow: View {
    let label: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(granted ? "Granted" : "Needed")
                .foregroundStyle(granted ? .green : .orange)
            if !granted {
                Button("Grant", action: action)
                    .pointerCursor()
            }
        }
    }
}

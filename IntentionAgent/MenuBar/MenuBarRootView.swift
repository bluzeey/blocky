import AppKit
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

            VStack(spacing: 0) {
                PermissionCardRow(label: "Accessibility", granted: appState.permissionSnapshot.accessibilityGranted) {
                    appState.requestAccessibilityPermission()
                }
                Divider()
                PermissionCardRow(label: "Screen Recording", granted: appState.permissionSnapshot.screenRecordingGranted) {
                    appState.requestScreenRecordingPermission()
                }
                Divider()
                PermissionCardRow(label: "Notifications", granted: appState.permissionSnapshot.notificationsGranted) {
                    Task {
                        await appState.requestNotificationPermission()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let session = appState.activeSession {
                Text("Current Intention")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(appState.sessionManager.remainingTimeText(for: session))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(session.isPaused ? "Resume" : "Pause") {
                        appState.togglePauseSession()
                    }
                    .font(.caption2)
                    .pointerCursor()

                    Button("End") {
                        appState.endSession()
                    }
                    .font(.caption2)
                    .pointerCursor()
                }

                Button("Allow 5 Min Drift") {
                    appState.allowDriftForFiveMinutes()
                }
                .font(.caption2)
                .pointerCursor()
            } else {
                Button("New Intention") {
                    appState.showIntentionModal()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .pointerCursor()
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Context")
                .font(.headline)

            HStack {
                Circle()
                    .fill(color(for: appState.currentAlignment))
                    .frame(width: 8, height: 8)
                Text(appState.currentMetadata.map { "\($0.activeAppName)" } ?? "No active context")
                    .font(.caption)
                Spacer()
                Text(appState.currentAlignment.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(color(for: appState.currentAlignment))
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Capture Library") {
                    openWindow(id: "capture-library")
                }
                .pointerCursor()

                Button("Settings") {
                    openWindow(id: "settings")
                }
                .pointerCursor()
            }

            Divider()

            Button("Quit Blocky") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundStyle(.secondary)
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

private struct PermissionCardRow: View {
    let label: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(granted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(granted ? "Granted" : "Needed")
                    .font(.caption)
                    .foregroundStyle(granted ? .green : .orange)
            }

            if !granted {
                Button("Grant", action: action)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.08))
                    )
                    .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }
}

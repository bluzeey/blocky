import AppKit
import SwiftUI

@MainActor
final class IntentionPanelController {
    private var panel: NSPanel?
    private var deactivationObserver: NSObjectProtocol?

    func show(appState: AppState) {
        if let panel, panel.isVisible { return }

        NSApp.activate(ignoringOtherApps: true)

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let contentView = FullScreenOverlayView(appState: appState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = screenFrame

        if let existingPanel = panel {
            existingPanel.contentView = hostingView
            existingPanel.setFrame(screenFrame, display: true)
            existingPanel.makeKeyAndOrderFront(nil)
            setupDeactivationObserver()
            Logger.log("IntentionModal", "Re-showing existing intention modal panel (full-screen)")
            return
        }

        let newPanel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .screenSaver
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = false
        newPanel.contentView = hostingView
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.isReleasedWhenClosed = false
        newPanel.hasShadow = false
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.hidesOnDeactivate = false

        panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        setupDeactivationObserver()
        Logger.log("IntentionModal", "Showing intention modal panel (full-screen lock)")
    }

    func hide() {
        removeDeactivationObserver()
        panel?.orderOut(nil)
        Logger.log("IntentionModal", "Hid intention modal panel")
    }

    private func setupDeactivationObserver() {
        removeDeactivationObserver()
        deactivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func removeDeactivationObserver() {
        if let observer = deactivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            deactivationObserver = nil
        }
    }
}

private struct FullScreenOverlayView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            IntentionModalView(appState: appState)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.black.opacity(0.6))
                        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

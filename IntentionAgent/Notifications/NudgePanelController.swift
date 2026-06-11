import AppKit
import SwiftUI

@MainActor
final class NudgePanelController {
    private var panel: NSPanel?
    private var autoDismissTask: Task<Void, Never>?

    func show(appState: AppState, sessionTitle: String, message: String) {
        hide()

        let contentView = NudgePopupView(appState: appState, sessionTitle: sessionTitle, message: message)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 300, height: 160)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 160),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.contentView = hostingView
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.isReleasedWhenClosed = false
        newPanel.hasShadow = true

        let screenRect = NSScreen.main!.visibleFrame
        let panelWidth = newPanel.frame.width
        let panelHeight = newPanel.frame.height
        let originX = screenRect.midX - panelWidth / 2
        let originY = screenRect.midY - panelHeight / 2
        newPanel.setFrameOrigin(NSPoint(x: originX, y: originY))

        panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        Logger.log("NudgePopup", "Showing nudge popup")

        autoDismissTask?.cancel()
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            self?.hide()
            Logger.log("NudgePopup", "Auto-dismissed after 30s (treated as on track)")
        }
    }

    func hide() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        panel?.orderOut(nil)
        Logger.log("NudgePopup", "Hid nudge popup")
    }
}

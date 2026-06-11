import AppKit
import SwiftUI

@MainActor
final class IntentionPanelController {
    private var panel: NSPanel?

    func show(appState: AppState) {
        if panel?.isVisible == true { return }

        let contentView = IntentionModalView(appState: appState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 380, height: 360)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
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
        Logger.log("IntentionModal", "Showing intention modal panel")
    }

    func hide() {
        panel?.orderOut(nil)
        Logger.log("IntentionModal", "Hid intention modal panel")
    }
}

import AppKit
import SwiftUI

@MainActor
final class IntentionPanelController {
    private var panel: NSPanel?

    func show(appState: AppState) {
        if let panel, panel.isVisible { return }

        NSApp.activate(ignoringOtherApps: true)

        let contentView = IntentionModalView(appState: appState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 380, height: 360)

        if let existingPanel = panel {
            existingPanel.contentView = hostingView
            existingPanel.center()
            existingPanel.makeKeyAndOrderFront(nil)
            Logger.log("IntentionModal", "Re-showing existing intention modal panel")
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.contentView = hostingView
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.isReleasedWhenClosed = false
        newPanel.hasShadow = true
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.center()

        panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        Logger.log("IntentionModal", "Showing intention modal panel")
    }

    func hide() {
        panel?.orderOut(nil)
        Logger.log("IntentionModal", "Hid intention modal panel")
    }
}

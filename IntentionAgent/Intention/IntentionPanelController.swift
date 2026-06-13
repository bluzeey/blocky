import AppKit
import SwiftUI

private final class BlockingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { return }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {}
}

private final class BackdropWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
}

@MainActor
final class IntentionPanelController {
    private var panel: BlockingPanel?
    private var backdrop: BackdropWindow?
    private var deactivationObserver: NSObjectProtocol?
    private var screenChangeObserver: NSObjectProtocol?

    func show(appState: AppState, initialTab: WorkModalTab = .intention, openAddTask: Bool = false) {
        if let panel, panel.isVisible { return }

        NSApp.activate(ignoringOtherApps: true)

        let panelRect = NSRect(x: 0, y: 0, width: 440, height: 520)

        let contentView = IntentionModalView(appState: appState, initialTab: initialTab, initiallyOpenAddTask: openAddTask)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panelRect

        if let existingPanel = panel {
            existingPanel.contentView = hostingView
            showBackdrop()
            existingPanel.center()
            existingPanel.makeKeyAndOrderFront(nil)
            setupDeactivationObserver()
            Logger.log("IntentionModal", "Re-showing existing intention modal panel")
            return
        }

        let newPanel = BlockingPanel(
            contentRect: panelRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = false
        newPanel.contentView = hostingView
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.isReleasedWhenClosed = false
        newPanel.hasShadow = true
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.center()

        panel = newPanel
        showBackdrop()
        newPanel.makeKeyAndOrderFront(nil)
        setupDeactivationObserver()
        setupScreenChangeObserver()
        Logger.log("IntentionModal", "Showing intention modal panel")
    }

    func hide() {
        removeDeactivationObserver()
        removeScreenChangeObserver()
        backdrop?.orderOut(nil)
        backdrop = nil
        panel?.orderOut(nil)
        Logger.log("IntentionModal", "Hid intention modal panel")
    }

    private func showBackdrop() {
        if let existingBackdrop = backdrop {
            updateBackdropFrame(existingBackdrop)
            existingBackdrop.orderFront(nil)
            return
        }

        guard let screen = NSScreen.main else { return }
        let backdropWindow = BackdropWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        backdropWindow.isOpaque = false
        backdropWindow.backgroundColor = NSColor(white: 0, alpha: 0.45)
        backdropWindow.hasShadow = false
        backdropWindow.ignoresMouseEvents = false
        backdropWindow.level = .normal
        backdropWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.backdrop = backdropWindow
        backdropWindow.orderFront(nil)
    }

    private func updateBackdropFrame(_ backdropWindow: BackdropWindow) {
        guard let screen = NSScreen.main else { return }
        backdropWindow.setFrame(screen.frame, display: true)
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

    private func setupScreenChangeObserver() {
        removeScreenChangeObserver()
        screenChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let backdrop = self.backdrop {
                    self.updateBackdropFrame(backdrop)
                }
                self.panel?.center()
            }
        }
    }

    private func removeScreenChangeObserver() {
        if let observer = screenChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            screenChangeObserver = nil
        }
    }
}

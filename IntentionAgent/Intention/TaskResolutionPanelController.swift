import AppKit
import SwiftUI

private final class ResolutionBlockingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func keyDown(with event: NSEvent) {}
    override func cancelOperation(_ sender: Any?) {}
}

private final class ResolutionBackdropWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
}

@MainActor
final class TaskResolutionPanelController {
    private var panel: ResolutionBlockingPanel?
    private var backdrop: ResolutionBackdropWindow?
    private var screenChangeObserver: NSObjectProtocol?

    func show(appState: AppState, taskTitle: String) {
        if let panel, panel.isVisible { return }

        NSApp.activate(ignoringOtherApps: true)

        let panelRect = NSRect(x: 0, y: 0, width: 360, height: 280)

        let contentView = TaskResolutionView(taskTitle: taskTitle) { resolution in
            appState.resolveTask(resolution)
        }
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panelRect

        if let existingPanel = panel {
            existingPanel.contentView = hostingView
            showBackdrop()
            existingPanel.center()
            existingPanel.makeKeyAndOrderFront(nil)
            Logger.log("TaskResolution", "Re-showing existing task resolution panel")
            return
        }

        let newPanel = ResolutionBlockingPanel(
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
        setupScreenChangeObserver()
        Logger.log("TaskResolution", "Showing task resolution panel")
    }

    func hide() {
        removeScreenChangeObserver()
        backdrop?.orderOut(nil)
        backdrop = nil
        panel?.orderOut(nil)
        Logger.log("TaskResolution", "Hid task resolution panel")
    }

    private func showBackdrop() {
        if let existingBackdrop = backdrop {
            updateBackdropFrame(existingBackdrop)
            existingBackdrop.orderFront(nil)
            return
        }

        guard let screen = NSScreen.main else { return }
        let backdropWindow = ResolutionBackdropWindow(
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

    private func updateBackdropFrame(_ backdropWindow: ResolutionBackdropWindow) {
        guard let screen = NSScreen.main else { return }
        backdropWindow.setFrame(screen.frame, display: true)
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

import SwiftUI

@main
struct IntentionAgentApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("IntentionAgent", systemImage: menuBarSymbolName) {
            MenuBarRootView(appState: appState)
        }

        Window("Capture Library", id: "capture-library") {
            CaptureLibraryView(appState: appState)
        }
        .defaultSize(width: 980, height: 680)

        Window("Settings", id: "settings") {
            SettingsView(appState: appState)
        }
        .defaultSize(width: 720, height: 620)
    }

    private var menuBarSymbolName: String {
        switch appState.currentAlignment {
        case .aligned:
            return "circle.fill"
        case .drift:
            return "exclamationmark.circle.fill"
        case .sensitive:
            return "lock.circle.fill"
        case .neutral, .unknown:
            return "circle.dashed"
        }
    }
}

import SwiftUI

@main
struct IntentionAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(appState: appState)
        } label: {
            MenuBarStatusIcon(alignment: appState.currentAlignment)
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

}

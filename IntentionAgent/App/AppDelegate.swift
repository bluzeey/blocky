import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.bootstrap()
        Logger.log("Lifecycle", "applicationDidFinishLaunching")
        Logger.log("Lifecycle", "Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        Logger.log("Lifecycle", "Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.log("Lifecycle", "applicationWillTerminate")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Logger.log("Lifecycle", "applicationDidBecomeActive")
    }
}

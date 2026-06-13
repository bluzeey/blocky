import AppKit
import Foundation

@MainActor
final class WindowMetadataService {
    func currentWindowMetadata() -> WindowMetadata? {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            Logger.log("WindowTracking", "No frontmost application")
            return nil
        }

        let processIdentifier = frontmostApplication.processIdentifier
        let appName = frontmostApplication.localizedName ?? "Unknown App"
        let bundleIdentifier = frontmostApplication.bundleIdentifier

        let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]

        let matchingWindowInfo = windowInfoList?.first { windowInfo in
            guard let windowOwnerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                return false
            }

            let windowLayer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            return windowOwnerPID == processIdentifier && windowLayer == 0
        }

        let windowTitle = matchingWindowInfo?[kCGWindowName as String] as? String
        let windowNumber = (matchingWindowInfo?[kCGWindowNumber as String] as? NSNumber)?.uint32Value

        var windowBounds: CGRect?
        if let boundsDictionary = matchingWindowInfo?[kCGWindowBounds as String] as? [String: Any] {
            windowBounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
        }

        let lowerBundle = bundleIdentifier?.lowercased() ?? ""
        let lowerAppName = appName.lowercased()
        var pageURL: String?
        var pageHost: String?

        if isBrowserApp(bundleIdentifier: lowerBundle, appName: lowerAppName) {
            let urlResult = fetchActiveTabURL(bundleIdentifier: lowerBundle, appName: lowerAppName)
            pageURL = urlResult
            if let url = urlResult, let host = extractHost(from: url) {
                pageHost = normalizeHost(host)
            }
        }

        let metadata = WindowMetadata(
            activeAppName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            windowID: windowNumber,
            windowBounds: windowBounds,
            timestamp: Date(),
            pageURL: pageURL,
            pageHost: pageHost
        )
        Logger.log("WindowTracking", "Resolved window metadata: app=\(metadata.activeAppName) title=\(metadata.windowTitle ?? "nil") bundle=\(metadata.bundleIdentifier ?? "nil") host=\(metadata.pageHost ?? "nil")")
        return metadata
    }

    private func isBrowserApp(bundleIdentifier: String, appName: String) -> Bool {
        bundleIdentifier.contains("com.google.chrome") ||
        bundleIdentifier.contains("company.thebrowser.browser") ||
        bundleIdentifier.contains("org.mozilla.firefox") ||
        bundleIdentifier.contains("com.apple.safari") ||
        bundleIdentifier.contains("com.operasoftware") ||
        appName.contains("chrome") ||
        appName.contains("safari") ||
        appName.contains("arc") ||
        appName.contains("firefox") ||
        appName.contains("opera")
    }

    private func fetchActiveTabURL(bundleIdentifier: String, appName: String) -> String? {
        if bundleIdentifier.contains("com.google.chrome") || appName.contains("chrome") {
            return fetchURLViaAppleScript(appName: "Google Chrome")
        }
        if bundleIdentifier.contains("company.thebrowser.browser") || appName.contains("arc") {
            return fetchURLViaAppleScript(appName: "Arc")
        }
        if bundleIdentifier.contains("com.apple.safari") || appName.contains("safari") {
            return fetchSafariURL()
        }
        if bundleIdentifier.contains("org.mozilla.firefox") || appName.contains("firefox") {
            return nil
        }
        return nil
    }

    private func fetchURLViaAppleScript(appName: String) -> String? {
        let script = """
        tell application "\(appName)"
            set theURL to URL of active tab of front window
            return theURL
        end tell
        """
        return runAppleScript(script)
    }

    private func fetchSafariURL() -> String? {
        let script = """
        tell application "Safari"
            set theURL to URL of front document
            return theURL
        end tell
        """
        return runAppleScript(script)
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }

    private func extractHost(from urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        return host
    }

    private func normalizeHost(_ host: String) -> String {
        let lower = host.lowercased()
        if lower.hasPrefix("www.") {
            return String(lower.dropFirst(4))
        }
        return lower
    }
}

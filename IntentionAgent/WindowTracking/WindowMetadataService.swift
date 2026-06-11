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

        let metadata = WindowMetadata(
            activeAppName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            windowID: windowNumber,
            windowBounds: windowBounds,
            timestamp: Date()
        )
        Logger.log("WindowTracking", "Resolved window metadata: app=\(metadata.activeAppName) title=\(metadata.windowTitle ?? "nil") bundle=\(metadata.bundleIdentifier ?? "nil") windowID=\(metadata.windowID.map(String.init) ?? "nil")")
        return metadata
    }
}

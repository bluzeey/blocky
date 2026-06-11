import Foundation
import CoreGraphics

enum CapturePolicy: String, Codable, CaseIterable {
    case noCapture
    case metadataOnly
    case redactedScreenshot
    case normalScreenshot
}

enum ActivityCategory: String, Codable, CaseIterable {
    case coding
    case email
    case video
    case socialMedia
    case messaging
    case payment
    case browsing
    case research
    case productivity
    case unknown
}

enum Alignment: String, Codable, CaseIterable {
    case aligned
    case drift
    case neutral
    case unknown
    case sensitive
}

struct WindowMetadata: Codable, Identifiable, Equatable {
    let id: UUID
    let activeAppName: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let windowID: UInt32?
    let windowBounds: CGRect?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        activeAppName: String,
        bundleIdentifier: String?,
        windowTitle: String?,
        windowID: UInt32?,
        windowBounds: CGRect?,
        timestamp: Date
    ) {
        self.id = id
        self.activeAppName = activeAppName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.windowID = windowID
        self.windowBounds = windowBounds
        self.timestamp = timestamp
    }
}

struct ContextEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let metadata: WindowMetadata
    let capturePolicy: CapturePolicy
    let category: ActivityCategory
    let safeSummary: String
    let alignment: Alignment
    let captureRecordID: UUID?
}

struct SafeEventSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let appName: String
    let contextLabel: String
    let durationSeconds: Int
    let policy: CapturePolicy
    let safeSummary: String
    let previewRecordID: UUID?
}

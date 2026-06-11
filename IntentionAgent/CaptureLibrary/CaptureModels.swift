import Foundation

struct CaptureRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let activeAppName: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let capturePolicy: CapturePolicy
    let activityCategory: ActivityCategory
    let alignment: Alignment
    let redactedPreviewPath: String?
    let rawScreenshotStored: Bool
    let safeSummary: String
    let aiPayloadPath: String?
    let skippedReason: String?
    let redactionReasons: [String]
    let sentToAI: Bool
    let privacyDecisionReason: String
}

struct AIPayloadRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionID: UUID
    let createdAt: Date
    let startedAt: Date
    let endedAt: Date
    let payloadPath: String
    let responseSummary: String
    let alignment: Alignment
}

import Foundation

struct FiveMinuteAIPayload: Codable {
    let sessionID: UUID
    let intention: String
    let startedAt: Date
    let endedAt: Date
    let eventSummaries: [SafeEventSummary]
    let screenshotRecords: [UUID]
    let sensitiveSkippedCount: Int
    let rawScreenshotsSent: Bool
    let rawScreenshotsStored: Bool
}

struct AIReviewResponse: Codable {
    let alignment: Alignment
    let message: String
    let suggestedAction: String
}

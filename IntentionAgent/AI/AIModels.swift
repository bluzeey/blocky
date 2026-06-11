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
    let suggestedAction: String?

    enum CodingKeys: String, CodingKey {
        case alignment
        case message
        case suggestedAction = "suggested_action"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alignment = try container.decode(Alignment.self, forKey: .alignment)
        message = try container.decode(String.self, forKey: .message)
        suggestedAction = try container.decodeIfPresent(String.self, forKey: .suggestedAction)
    }
}

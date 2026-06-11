import Foundation

struct AIPayloadBuilder {
    private let aggregator = ContextAggregator()

    func buildPayload(session: IntentionSession, records: [CaptureRecord], defaultIntervalSeconds: Int) -> FiveMinuteAIPayload {
        let summaries = aggregator.aggregate(records: records, defaultIntervalSeconds: defaultIntervalSeconds)

        return FiveMinuteAIPayload(
            sessionID: session.id,
            intention: session.title,
            startedAt: records.first?.timestamp ?? session.startedAt,
            endedAt: records.last?.timestamp ?? Date(),
            eventSummaries: summaries,
            screenshotRecords: records.filter { $0.redactedPreviewPath != nil }.map(\.id),
            sensitiveSkippedCount: aggregator.sensitiveSkippedCount(records: records),
            rawScreenshotsSent: false,
            rawScreenshotsStored: false
        )
    }
}

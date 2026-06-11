import Foundation

struct ContextAggregator {
    func aggregate(records: [CaptureRecord], defaultIntervalSeconds: Int) -> [SafeEventSummary] {
        guard !records.isEmpty else { return [] }

        var summariesByContext: [String: SafeEventSummary] = [:]

        for (index, record) in records.enumerated() {
            let nextTimestamp = index + 1 < records.count ? records[index + 1].timestamp : record.timestamp.addingTimeInterval(TimeInterval(defaultIntervalSeconds))
            let durationSeconds = max(1, Int(nextTimestamp.timeIntervalSince(record.timestamp)))
            let contextLabel = record.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? record.activeAppName
            let aggregationKey = "\(record.activeAppName)|\(contextLabel)|\(record.capturePolicy.rawValue)|\(record.safeSummary)"

            let existingSummary = summariesByContext[aggregationKey]
            let updatedSummary = SafeEventSummary(
                id: existingSummary?.id ?? UUID(),
                appName: record.activeAppName,
                contextLabel: contextLabel,
                durationSeconds: (existingSummary?.durationSeconds ?? 0) + durationSeconds,
                policy: record.capturePolicy,
                safeSummary: record.safeSummary,
                previewRecordID: record.redactedPreviewPath == nil ? existingSummary?.previewRecordID : record.id
            )

            summariesByContext[aggregationKey] = updatedSummary
        }

        return summariesByContext.values.sorted { $0.durationSeconds > $1.durationSeconds }
    }

    func sensitiveSkippedCount(records: [CaptureRecord]) -> Int {
        records.filter { $0.capturePolicy == .noCapture || $0.skippedReason != nil && $0.capturePolicy == .metadataOnly }.count
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

import SwiftUI

struct CaptureLibraryView: View {
    @ObservedObject var appState: AppState
    @State private var selectedRecordID: UUID?

    var body: some View {
        NavigationSplitView {
            List(appState.captureLibraryStore.captureRecords, selection: $selectedRecordID) { record in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(record.timestamp.captureTimeText) - \(record.activeAppName)")
                        .font(.headline)
                    if let windowTitle = record.windowTitle, !windowTitle.isEmpty {
                        Text(windowTitle)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    Text("Policy: \(record.capturePolicy.rawValue) | Alignment: \(record.alignment.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(record.safeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        } detail: {
            if let selectedRecord = appState.captureLibraryStore.captureRecords.first(where: { $0.id == selectedRecordID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedRecord.activeAppName)
                            .font(.largeTitle)
                        Text(selectedRecord.timestamp.captureTimeText)
                            .foregroundStyle(.secondary)

                        if let previewImage = appState.captureLibraryStore.previewImage(for: selectedRecord) {
                            Image(nsImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 720)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 280)
                                .overlay(Text(selectedRecord.skippedReason ?? "No screenshot stored"))
                        }

                        DetailRow(label: "Window", value: selectedRecord.windowTitle ?? "Unknown")
                        DetailRow(label: "Policy", value: selectedRecord.capturePolicy.rawValue)
                        DetailRow(label: "Summary", value: selectedRecord.safeSummary)
                        DetailRow(label: "Sent to AI", value: selectedRecord.sentToAI ? "Yes" : "No")
                        DetailRow(label: "Reason", value: selectedRecord.privacyDecisionReason)

                        if !selectedRecord.redactionReasons.isEmpty {
                            Text("Redaction reasons")
                                .font(.headline)
                            ForEach(selectedRecord.redactionReasons, id: \.self) { reason in
                                Text(reason)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Select a capture", systemImage: "photo.on.rectangle.angled")
            }
        }
        .navigationTitle("Capture Library")
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

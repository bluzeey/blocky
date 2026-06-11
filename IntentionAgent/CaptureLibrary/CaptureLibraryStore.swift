import AppKit
import Combine
import Foundation

@MainActor
final class CaptureLibraryStore: ObservableObject {
    @Published private(set) var captureRecords: [CaptureRecord] = []
    @Published private(set) var payloadRecords: [AIPayloadRecord] = []

    private let fileManager = FileManager.default
    private let fileSystemLayout = FileSystemLayout()
    private let sqliteStore: SQLiteStore

    init() {
        do {
            try fileSystemLayout.createDirectoriesIfNeeded(fileManager: fileManager)
            sqliteStore = try SQLiteStore(databaseURL: fileSystemLayout.databaseURL)
            try reload()
            Logger.log("CaptureLibrary", "Initialized capture library store at \(fileSystemLayout.captureLibraryURL.path)")
        } catch {
            fatalError("Failed to initialize CaptureLibraryStore: \(error.localizedDescription)")
        }
    }

    func reload() throws {
        captureRecords = try sqliteStore.fetchCaptureRecords(limit: 300)
        payloadRecords = try sqliteStore.fetchPayloadRecords(limit: 100)
        Logger.log("CaptureLibrary", "Reloaded store with \(captureRecords.count) captures and \(payloadRecords.count) payloads")
    }

    func records(from startDate: Date, to endDate: Date) throws -> [CaptureRecord] {
        try sqliteStore.fetchCaptureRecords(from: startDate, to: endDate)
    }

    func saveCaptureRecord(_ record: CaptureRecord, previewData: Data?) throws {
        Logger.log("CaptureLibrary", "Saving capture record id=\(record.id.uuidString) app=\(record.activeAppName) policy=\(record.capturePolicy.rawValue) previewStored=\(previewData != nil)")
        if let previewData, let previewPath = record.redactedPreviewPath {
            let previewURL = URL(fileURLWithPath: previewPath)
            try fileManager.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try previewData.write(to: previewURL, options: .atomic)
            Logger.log("CaptureLibrary", "Wrote preview to \(previewURL.path)")
        }

        try sqliteStore.insertCaptureRecord(record)

        if record.skippedReason != nil {
            try appendSkippedEventLine(for: record)
        }

        try reload()
    }

    func savePayloadRecord(_ record: AIPayloadRecord, payloadData: Data) throws {
        let payloadURL = URL(fileURLWithPath: record.payloadPath)
        try fileManager.createDirectory(at: payloadURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try payloadData.write(to: payloadURL, options: .atomic)
        try sqliteStore.insertPayloadRecord(record)
        Logger.log("CaptureLibrary", "Saved AI payload record id=\(record.id.uuidString) path=\(record.payloadPath)")
        try reload()
    }

    func previewImage(for record: CaptureRecord) -> NSImage? {
        guard let redactedPreviewPath = record.redactedPreviewPath else { return nil }
        return NSImage(contentsOfFile: redactedPreviewPath)
    }

    func payloadText(for record: AIPayloadRecord) -> String {
        (try? String(contentsOfFile: record.payloadPath, encoding: .utf8)) ?? "Payload unavailable"
    }

    func previewPath(for captureID: UUID, timestamp: Date) -> String {
        let previewDirectory = fileSystemLayout.previewDirectory(for: timestamp)
        let previewURL = previewDirectory.appendingPathComponent("\(captureID.uuidString)_redacted.jpg")
        return previewURL.path
    }

    func payloadPath(for payloadID: UUID, timestamp: Date) -> String {
        let payloadDirectory = fileSystemLayout.payloadDirectory(for: timestamp)
        let payloadURL = payloadDirectory.appendingPathComponent("\(payloadID.uuidString)_payload.json")
        return payloadURL.path
    }

    func deleteAll() throws {
        Logger.log("CaptureLibrary", "Deleting all stored captures and payloads")
        try sqliteStore.deleteAllRecords()

        for directoryURL in [fileSystemLayout.previewsURL, fileSystemLayout.payloadsURL, fileSystemLayout.skippedURL, fileSystemLayout.exportsURL] {
            if fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.removeItem(at: directoryURL)
            }
        }

        try fileSystemLayout.createDirectoriesIfNeeded(fileManager: fileManager)
        try reload()
    }

    private func appendSkippedEventLine(for record: CaptureRecord) throws {
        let recordData = try JSONEncoder().encode(record)
        var lineData = recordData
        lineData.append(Data([0x0A]))

        if fileManager.fileExists(atPath: fileSystemLayout.skippedEventsURL.path) {
            let handle = try FileHandle(forWritingTo: fileSystemLayout.skippedEventsURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: lineData)
        } else {
            try lineData.write(to: fileSystemLayout.skippedEventsURL, options: .atomic)
        }
        Logger.log("CaptureLibrary", "Appended skipped event for record id=\(record.id.uuidString)")
    }
}

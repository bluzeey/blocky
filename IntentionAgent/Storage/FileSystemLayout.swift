import Foundation

struct FileSystemLayout {
    let rootURL: URL
    let captureLibraryURL: URL
    let previewsURL: URL
    let payloadsURL: URL
    let skippedURL: URL
    let exportsURL: URL
    let databaseURL: URL
    let skippedEventsURL: URL

    init(fileManager: FileManager = .default) {
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = applicationSupportURL.appendingPathComponent("IntentionAgent", isDirectory: true)
        captureLibraryURL = rootURL.appendingPathComponent("CaptureLibrary", isDirectory: true)
        previewsURL = captureLibraryURL.appendingPathComponent("previews", isDirectory: true)
        payloadsURL = captureLibraryURL.appendingPathComponent("payloads", isDirectory: true)
        skippedURL = captureLibraryURL.appendingPathComponent("skipped", isDirectory: true)
        exportsURL = captureLibraryURL.appendingPathComponent("exports", isDirectory: true)
        databaseURL = captureLibraryURL.appendingPathComponent("index.sqlite")
        skippedEventsURL = skippedURL.appendingPathComponent("skipped_events.jsonl")
    }

    func createDirectoriesIfNeeded(fileManager: FileManager = .default) throws {
	        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
	        try fileManager.createDirectory(at: captureLibraryURL, withIntermediateDirectories: true, attributes: nil)
	        try fileManager.createDirectory(at: previewsURL, withIntermediateDirectories: true, attributes: nil)
	        try fileManager.createDirectory(at: payloadsURL, withIntermediateDirectories: true, attributes: nil)
	        try fileManager.createDirectory(at: skippedURL, withIntermediateDirectories: true, attributes: nil)
	        try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true, attributes: nil)
    }

    func previewDirectory(for date: Date) -> URL {
        previewsURL.appendingPathComponent(date.dayFolderComponent, isDirectory: true)
    }

    func payloadDirectory(for date: Date) -> URL {
        payloadsURL.appendingPathComponent(date.dayFolderComponent, isDirectory: true)
    }
}

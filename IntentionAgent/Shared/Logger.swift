import Foundation

enum Logger {
    private static let fileWriter = LogFileWriter.shared

    static func bootstrap() {
        fileWriter.bootstrap()
        log("Bootstrap", "Logger bootstrapped")
    }

    nonisolated static func log(_ category: String, _ message: String) {
        let timestamp = DateFormatting.jsonTimestampFormatter.string(from: Date())
        let formattedMessage = "[\(timestamp)][IntentionAgent][\(category)] \(message)"
        print(formattedMessage)
        Task.detached(priority: .utility) {
            await fileWriter.append(formattedMessage)
        }
    }
}

actor LogFileWriter {
    static let shared = LogFileWriter()

    private let fileManager = FileManager.default
    private var logFileURL: URL?

    func bootstrap() {
        guard logFileURL == nil else { return }

        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logsDirectoryURL = applicationSupportURL
            .appendingPathComponent("IntentionAgent", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)

        do {
            try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            logFileURL = logsDirectoryURL.appendingPathComponent("intention-agent.log")
        } catch {
            print("[IntentionAgent][Bootstrap] Failed to prepare log directory: \(error.localizedDescription)")
        }
    }

    func append(_ line: String) {
        guard let logFileURL else { return }

        let lineData = Data((line + "\n").utf8)
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
            } else {
                try lineData.write(to: logFileURL, options: .atomic)
            }
        } catch {
            print("[IntentionAgent][Bootstrap] Failed to append log: \(error.localizedDescription)")
        }
    }
}

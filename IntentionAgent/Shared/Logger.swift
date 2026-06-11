import Foundation

enum Logger {
    nonisolated static func log(_ category: String, _ message: String) {
        print("[IntentionAgent][\(category)] \(message)")
    }
}

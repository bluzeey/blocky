import Foundation

struct IntentionSession: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let startedAt: Date
    let endsAt: Date
    let allowedApps: [String]
    let allowedCategories: [ActivityCategory]
    let blockedApps: [String]
    let blockedCategories: [ActivityCategory]
    let aiReviewIntervalSeconds: Int
    var pauseStartedAt: Date?
    var totalPausedSeconds: Int
    let source: SessionSource
    let taskId: UUID?
    let expectedHosts: [String]

    var isPaused: Bool {
        pauseStartedAt != nil
    }

    var isTaskBacked: Bool {
        taskId != nil
    }
}

struct SessionDraft: Equatable {
    var title: String = ""
    var durationMinutes: Int = 30
    var allowedAppsText: String = ""
    var blockedAppsText: String = ""
    var allowedCategories: Set<ActivityCategory> = []
    var blockedCategories: Set<ActivityCategory> = []
    var source: SessionSource = .intention
    var taskId: UUID? = nil

    var isExploration: Bool {
        source == .exploration
    }

    var expectedHosts: [String] {
        DomainParser.parseHosts(from: title)
    }
}

extension SessionDraft {
    func buildSession(reviewIntervalSeconds: Int) -> IntentionSession {
        let now = Date()
        return IntentionSession(
            id: UUID(),
            title: title.isEmpty ? "Untitled intention" : title,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            allowedApps: allowedAppsText.csvList,
            allowedCategories: allowedCategories.sorted { $0.rawValue < $1.rawValue },
            blockedApps: blockedAppsText.csvList,
            blockedCategories: blockedCategories.sorted { $0.rawValue < $1.rawValue },
            aiReviewIntervalSeconds: reviewIntervalSeconds,
            pauseStartedAt: nil,
            totalPausedSeconds: 0,
            source: source,
            taskId: taskId,
            expectedHosts: expectedHosts
        )
    }
}

private extension String {
    var csvList: [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum DomainParser {
    static func parseHosts(from text: String) -> [String] {
        let tldPattern = #"(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: tldPattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        var hosts: [String] = []
        for match in matches {
            if let swiftRange = Range(match.range, in: text) {
                let raw = String(text[swiftRange]).lowercased()
                let normalized = raw.hasPrefix("www.") ? String(raw.dropFirst(4)) : raw
                if !hosts.contains(normalized) {
                    hosts.append(normalized)
                }
            }
        }
        return hosts
    }
}

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
            taskId: taskId
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

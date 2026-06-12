import Foundation

enum TaskListType: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

enum SessionSource: String, Codable, Equatable {
    case intention
    case dailyTask = "daily_task"
    case weeklyTask = "weekly_task"
    case exploration
}

struct FocusTask: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var durationMinutes: Int
    var listType: TaskListType
    var completedAt: Date?
    var createdAt: Date

    var isCompleted: Bool {
        completedAt != nil
    }

    init(
        id: UUID = UUID(),
        title: String,
        durationMinutes: Int,
        listType: TaskListType,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.listType = listType
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}

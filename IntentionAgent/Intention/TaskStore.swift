import Combine
import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var dailyTasks: [FocusTask] = []
    @Published private(set) var weeklyTasks: [FocusTask] = []

    private let sqliteStore: SQLiteStore

    init(sqliteStore: SQLiteStore) {
        self.sqliteStore = sqliteStore
        reload()
        Logger.log("TaskStore", "Initialized task store")
    }

    func reload() {
        do {
            let allTasks = try sqliteStore.fetchFocusTasks()
            dailyTasks = allTasks.filter { $0.listType == .daily && !$0.isCompleted }
            weeklyTasks = allTasks.filter { $0.listType == .weekly && !$0.isCompleted }
            Logger.log("TaskStore", "Reloaded tasks: \(dailyTasks.count) daily, \(weeklyTasks.count) weekly")
        } catch {
            Logger.log("TaskStore", "Failed to reload tasks: \(error.localizedDescription)")
        }
    }

    func addTask(title: String, durationMinutes: Int, listType: TaskListType) -> FocusTask {
        let task = FocusTask(
            title: title,
            durationMinutes: durationMinutes,
            listType: listType
        )
        do {
            try sqliteStore.insertFocusTask(task)
            reload()
            Logger.log("TaskStore", "Added task: \(title) (\(durationMinutes) min, \(listType.rawValue))")
        } catch {
            Logger.log("TaskStore", "Failed to add task: \(error.localizedDescription)")
        }
        return task
    }

    func markCompleted(id: UUID) {
        do {
            try sqliteStore.updateFocusTaskCompleted(id: id, completedAt: Date())
            reload()
            Logger.log("TaskStore", "Marked task completed: \(id.uuidString)")
        } catch {
            Logger.log("TaskStore", "Failed to mark task completed: \(error.localizedDescription)")
        }
    }

    func task(withId id: UUID) -> FocusTask? {
        dailyTasks.first(where: { $0.id == id }) ?? weeklyTasks.first(where: { $0.id == id })
    }
}

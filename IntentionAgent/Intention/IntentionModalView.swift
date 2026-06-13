import SwiftUI

enum WorkModalTab: String, CaseIterable, Identifiable {
    case intention
    case daily
    case weekly
    case exploration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .intention: return "Intention"
        case .daily: return "Daily Tasks"
        case .weekly: return "Weekly Tasks"
        case .exploration: return "Explore"
        }
    }
}

struct IntentionModalView: View {
    @ObservedObject var appState: AppState

    var initialTab: WorkModalTab = .intention
    var initiallyOpenAddTask: Bool = false

    @State private var activeTab: WorkModalTab = .intention
    @State private var intentionText: String = ""
    @State private var durationMinutes: Int = 30
    @State private var selectedDailyTaskId: UUID? = nil
    @State private var selectedWeeklyTaskId: UUID? = nil
    @State private var isAddTaskOpen: Bool = false

    private var canStart: Bool {
        switch activeTab {
        case .intention:
            return !intentionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .daily:
            return selectedDailyTaskId != nil
        case .weekly:
            return selectedWeeklyTaskId != nil
        case .exploration:
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 20)

            segmentedTabControl
                .padding(.bottom, 16)

            tabContent
                .frame(maxHeight: .infinity)
                .padding(.bottom, 16)

            durationSection
                .padding(.bottom, 20)

            actionButtons
        }
        .padding(28)
        .frame(width: 440, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            intentionText = ""
            durationMinutes = 30
            selectedDailyTaskId = nil
            selectedWeeklyTaskId = nil
            activeTab = initialTab
            isAddTaskOpen = initiallyOpenAddTask
        }
    }

    private var header: some View {
        Text("What are you working on?")
            .font(.title2.bold())
    }

    private var segmentedTabControl: some View {
        HStack(spacing: 0) {
            ForEach(WorkModalTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        activeTab = tab
                        isAddTaskOpen = false
                    }
                }) {
                    Text(tab.displayName)
                        .font(.subheadline)
                        .fontWeight(activeTab == tab ? .semibold : .regular)
                        .foregroundStyle(activeTab == tab ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(activeTab == tab ? Color.blue.opacity(0.25) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .intention:
            intentionContent
        case .daily:
            dailyContent
        case .weekly:
            weeklyContent
        case .exploration:
            explorationContent
        }
    }

    private var intentionContent: some View {
        TextField("e.g. Write project report", text: $intentionText)
            .textFieldStyle(.roundedBorder)
            .font(.body)
            .onSubmit {
                if canStart { startSession() }
            }
    }

    private var dailyContent: some View {
        VStack(spacing: 12) {
            if isAddTaskOpen {
                AddTaskView(
                    listType: .daily,
                    onAdd: { task in
                        _ = appState.taskStore.addTask(
                            title: task.title,
                            durationMinutes: task.durationMinutes,
                            listType: .daily
                        )
                        selectedDailyTaskId = task.id
                        durationMinutes = task.durationMinutes
                        isAddTaskOpen = false
                    },
                    onCancel: {
                        isAddTaskOpen = false
                    }
                )
            }

            TaskListView(
                tasks: appState.taskStore.dailyTasks,
                selectedTaskId: selectedDailyTaskId,
                onSelect: { task in
                    selectedDailyTaskId = task.id
                    durationMinutes = task.durationMinutes
                },
                onDelete: { task in
                    appState.taskStore.deleteTask(id: task.id)
                    if selectedDailyTaskId == task.id {
                        selectedDailyTaskId = nil
                        durationMinutes = 30
                    }
                },
                onAddTask: {
                    isAddTaskOpen.toggle()
                },
                listTitle: "Daily Tasks",
                emptyMessage: "No daily tasks yet.\nAdd one to start a focused session.",
                emptyButtonTitle: "Add Daily Task"
            )
        }
    }

    private var weeklyContent: some View {
        VStack(spacing: 12) {
            if isAddTaskOpen {
                AddTaskView(
                    listType: .weekly,
                    onAdd: { task in
                        _ = appState.taskStore.addTask(
                            title: task.title,
                            durationMinutes: task.durationMinutes,
                            listType: .weekly
                        )
                        selectedWeeklyTaskId = task.id
                        durationMinutes = task.durationMinutes
                        isAddTaskOpen = false
                    },
                    onCancel: {
                        isAddTaskOpen = false
                    }
                )
            }

            TaskListView(
                tasks: appState.taskStore.weeklyTasks,
                selectedTaskId: selectedWeeklyTaskId,
                onSelect: { task in
                    selectedWeeklyTaskId = task.id
                    durationMinutes = task.durationMinutes
                },
                onDelete: { task in
                    appState.taskStore.deleteTask(id: task.id)
                    if selectedWeeklyTaskId == task.id {
                        selectedWeeklyTaskId = nil
                        durationMinutes = 30
                    }
                },
                onAddTask: {
                    isAddTaskOpen.toggle()
                },
                listTitle: "Weekly Tasks",
                emptyMessage: "No weekly tasks yet.\nAdd one to plan your week.",
                emptyButtonTitle: "Add Weekly Task"
            )
        }
    }

    private var explorationContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 28))
                .foregroundStyle(.blue.opacity(0.6))

            Text("Work freely without tracking or nudges")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("No screenshots, no alignment checks, no drift alerts.\nJust a timer for your session.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private var durationSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("", value: $durationMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .font(.subheadline)
                Text("min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(value: Binding(
                get: { Double(durationMinutes) },
                set: { durationMinutes = Int($0) }
            ), in: 5...240, step: 5)
        }
    }

    private var actionButtons: some View {
        HStack {
            Spacer()

            Button("Start") {
                startSession()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canStart)
            .pointerCursor()
        }
    }

    private func startSession() {
        let source: SessionSource
        let sessionTitle: String
        var taskId: UUID? = nil

        switch activeTab {
        case .intention:
            source = .intention
            sessionTitle = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .daily:
            guard let id = selectedDailyTaskId,
                  let task = appState.taskStore.task(withId: id) else { return }
            source = .dailyTask
            sessionTitle = task.title
            taskId = task.id
        case .weekly:
            guard let id = selectedWeeklyTaskId,
                  let task = appState.taskStore.task(withId: id) else { return }
            source = .weeklyTask
            sessionTitle = task.title
            taskId = task.id
        case .exploration:
            source = .exploration
            sessionTitle = "Exploration"
        }

        appState.sessionDraft = SessionDraft(
            title: sessionTitle,
            durationMinutes: durationMinutes,
            source: source,
            taskId: taskId
        )
        appState.startSessionFromDraft()
    }
}

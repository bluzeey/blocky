import SwiftUI

struct TaskListView: View {
    let tasks: [FocusTask]
    let selectedTaskId: UUID?
    let onSelect: (FocusTask) -> Void
    let onAddTask: () -> Void
    let listTitle: String
    let emptyMessage: String
    let emptyButtonTitle: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(listTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onAddTask) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2)
                        Text("Add Task")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .pointerCursor()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            if tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAddTask) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption2)
                    Text(emptyButtonTitle)
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(.blue.opacity(0.15))
                )
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        isSelected: selectedTaskId == task.id,
                        onSelect: { onSelect(task) }
                    )
                }
            }
        }
    }
}

private struct TaskRowView: View {
    let task: FocusTask
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .symbolEffect(.bounce, value: isSelected)

                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text("\(task.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return .blue.opacity(0.1)
        } else if isHovered {
            return .white.opacity(0.06)
        } else {
            return .clear
        }
    }
}

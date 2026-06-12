import SwiftUI

struct AddTaskView: View {
    let listType: TaskListType
    let onAdd: (FocusTask) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var durationMinutes: Int = 30
    @FocusState private var isTitleFocused: Bool

    private var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && durationMinutes >= 5 && durationMinutes <= 240
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Add \(listType.displayName) Task")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Task")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g. Reply to investor email", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .focused($isTitleFocused)
                    .onSubmit {
                        if isValid { addTask() }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(durationMinutes) },
                        set: { durationMinutes = Int($0) }
                    ), in: 5...240, step: 5)

                    TextField("", value: $durationMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .font(.subheadline)

                    Text("min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .pointerCursor()

                Spacer()

                Button("Add Task") {
                    addTask()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .pointerCursor()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            isTitleFocused = true
        }
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, durationMinutes >= 5, durationMinutes <= 240 else { return }
        let task = FocusTask(
            title: trimmed,
            durationMinutes: durationMinutes,
            listType: listType
        )
        onAdd(task)
    }
}

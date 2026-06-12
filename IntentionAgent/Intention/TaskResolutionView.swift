import SwiftUI

enum TaskResolution: Equatable {
    case completed
    case continueLater
    case cancel
}

struct TaskResolutionView: View {
    let taskTitle: String
    let onResolve: (TaskResolution) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("What happened with your task?")
                .font(.title2.bold())

            Text(taskTitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            VStack(spacing: 10) {
                Button {
                    onResolve(.completed)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                        Text("Completed")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .pointerCursor()

                Button {
                    onResolve(.continueLater)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body)
                        Text("Continue Later")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .pointerCursor()

                Button {
                    onResolve(.cancel)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .font(.body)
                        Text("Cancel")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .foregroundStyle(.secondary)
                .pointerCursor()
            }
        }
        .padding(28)
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

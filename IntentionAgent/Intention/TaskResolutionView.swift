import SwiftUI

enum TaskResolution: Equatable {
    case completed
    case continueLater
    case cancel
}

struct TaskResolutionView: View {
    let sessionTitle: String
    let isTaskBacked: Bool
    let onResolve: (TaskResolution) -> Void

    private var headlineText: String {
        isTaskBacked ? "What happened with your task?" : "What happened with your current intention?"
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(headlineText)
                .font(.title2.bold())

            Text(sessionTitle)
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
                        Image(systemName: "arrow.triangle.swap.auto")
                            .font(.body)
                        Text(isTaskBacked ? "Got another task" : "Switch intention")
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
                        Text("Stay on current")
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

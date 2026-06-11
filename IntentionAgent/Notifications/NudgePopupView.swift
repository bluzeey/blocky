import SwiftUI

struct NudgePopupView: View {
    @ObservedObject var appState: AppState
    let sessionTitle: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Text(sessionTitle)
                .font(.headline)

            Text(message.isEmpty ? "Are you still on track?" : message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("No, I drifted") {
                    appState.acknowledgeNudge(isOnTrack: false)
                }
                .pointerCursor()

                Button("Yes, on track") {
                    appState.acknowledgeNudge(isOnTrack: true)
                }
                .buttonStyle(.borderedProminent)
                .pointerCursor()
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

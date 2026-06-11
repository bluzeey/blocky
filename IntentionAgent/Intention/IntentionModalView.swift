import SwiftUI

struct IntentionModalView: View {
    @ObservedObject var appState: AppState
    @State private var title: String = ""
    @State private var durationMinutes: Int = 30
    @State private var allowedAppsText: String = ""
    @State private var blockedAppsText: String = ""
    @State private var showingDetails: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("What are you working on?")
                .font(.title2.bold())

            TextField("e.g. Write project report", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.body)

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

            Button(showingDetails ? "Hide app filters" : "Add app filters") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingDetails.toggle()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if showingDetails {
                VStack(spacing: 8) {
                    TextField("Allowed apps (comma separated)", text: $allowedAppsText)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    TextField("Blocked apps (comma separated)", text: $blockedAppsText)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    appState.hideIntentionModal()
                }
                .keyboardShortcut(.cancelAction)
                .pointerCursor()

                Button("Start") {
                    appState.sessionDraft = SessionDraft(
                        title: title,
                        durationMinutes: durationMinutes,
                        allowedAppsText: allowedAppsText,
                        blockedAppsText: blockedAppsText
                    )
                    appState.startSessionFromDraft()
                    appState.hideIntentionModal()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .pointerCursor()
            }
        }
        .padding(28)
        .frame(width: 380)
        .onAppear {
            title = ""
            durationMinutes = 30
            allowedAppsText = ""
            blockedAppsText = ""
            showingDetails = false
        }
    }
}

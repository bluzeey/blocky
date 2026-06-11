import SwiftUI

struct IntentionModalView: View {
    @ObservedObject var appState: AppState
    @State private var title: String = ""
    @State private var durationMinutes: Int = 30

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

            HStack(spacing: 16) {
                Button("Cancel") {
                    appState.hideIntentionModal()
                }
                .keyboardShortcut(.cancelAction)
                .pointerCursor()

                Button("Start") {
                    appState.sessionDraft = SessionDraft(
                        title: title,
                        durationMinutes: durationMinutes
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
        }
    }
}

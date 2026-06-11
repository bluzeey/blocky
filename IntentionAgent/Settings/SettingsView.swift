import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var draftSettings: AppSettings = .default

    var body: some View {
        Form {
            Section("Umans") {
                SecureField("API Key", text: $draftSettings.umansAPIKey)
                TextField("Base URL", text: $draftSettings.umansBaseURLString)
                Picker("Model", selection: $draftSettings.umansModelName) {
                    Text("umans-coder").tag("umans-coder")
                    Text("umans-kimi-k2.6").tag("umans-kimi-k2.6")
                    Text("umans-glm-5.1").tag("umans-glm-5.1")
                    Text("umans-flash").tag("umans-flash")
                }
            }

            Section("Intervals") {
                Stepper(value: $draftSettings.metadataPollIntervalSeconds, in: 5...30) {
                    Text("Metadata poll: \(draftSettings.metadataPollIntervalSeconds) seconds")
                }
                Stepper(value: $draftSettings.screenshotIntervalSeconds, in: 15...120) {
                    Text("Screenshot interval: \(draftSettings.screenshotIntervalSeconds) seconds")
                }
                Stepper(value: $draftSettings.aiReviewIntervalSeconds, in: 60...900, step: 60) {
                    Text("AI review interval: \(draftSettings.aiReviewIntervalSeconds / 60) minutes")
                }
                Stepper(value: $draftSettings.retentionHours, in: 1...168) {
                    Text("Retention: \(draftSettings.retentionHours) hours")
                }
            }

            Section("Privacy") {
                Toggle("Store redacted previews", isOn: $draftSettings.storeRedactedPreviews)
                Toggle("Send redacted images to AI", isOn: $draftSettings.sendRedactedImagesToAI)
                Toggle("Strict mode", isOn: $draftSettings.strictModeEnabled)
            }

            Section("Rule Extensions") {
                TextField("Blocked app keywords (comma separated)", text: Binding(
                    get: { draftSettings.userBlockedAppKeywords.joined(separator: ", ") },
                    set: { draftSettings.userBlockedAppKeywords = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                ))

                TextField("Sensitive title keywords (comma separated)", text: Binding(
                    get: { draftSettings.userSensitiveTitleKeywords.joined(separator: ", ") },
                    set: { draftSettings.userSensitiveTitleKeywords = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
                ))
            }

            Section {
                Button("Save Settings") {
                    appState.saveSettings(draftSettings)
                }
                .pointerCursor()

                Button("Delete All Captures") {
                    appState.deleteAllCaptures()
                }
                .foregroundStyle(.red)
                .pointerCursor()
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            draftSettings = appState.settings
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var draftSettings: AppSettings = .default

    var body: some View {
        Form {
            Section("AI") {
                Picker("Provider", selection: $draftSettings.aiProvider) {
                    ForEach(AIProviderPreset.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                SecureField("API Key", text: $draftSettings.aiAPIKey)
                TextField("Base URL", text: $draftSettings.aiBaseURLString)
                TextField("Model", text: $draftSettings.aiModelName)
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
        .onChange(of: draftSettings.aiProvider) { oldValue, newValue in
            if draftSettings.aiBaseURLString == oldValue.defaultBaseURLString || draftSettings.aiBaseURLString.isEmpty {
                draftSettings.aiBaseURLString = newValue.defaultBaseURLString
            }
            if draftSettings.aiModelName == oldValue.defaultModelName || draftSettings.aiModelName.isEmpty {
                draftSettings.aiModelName = newValue.defaultModelName
            }
        }
    }
}

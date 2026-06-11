import Combine
import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "IntentionAgent.AppSettings"

    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decodedSettings
            Logger.log("Settings", "Loaded persisted settings")
        } else {
            settings = .default
            Logger.log("Settings", "Using default settings")
        }
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        var nextSettings = settings
        mutate(&nextSettings)
        settings = nextSettings
        persist()
    }

    func replace(with settings: AppSettings) {
        self.settings = settings
        persist()
    }

    private func persist() {
        guard let encodedSettings = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(encodedSettings, forKey: settingsKey)
        Logger.log("Settings", "Persisted settings update")
    }
}

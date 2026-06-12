import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    func register() -> Bool {
        do {
            try SMAppService.mainApp.register()
            Logger.log("LaunchAtLogin", "Registered as login item")
            return true
        } catch {
            Logger.log("LaunchAtLogin", "Failed to register: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func unregister() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            Logger.log("LaunchAtLogin", "Unregistered login item")
            return true
        } catch {
            Logger.log("LaunchAtLogin", "Failed to unregister: \(error.localizedDescription)")
            return false
        }
    }

    func apply(_ enabled: Bool) {
        if enabled {
            register()
        } else {
            unregister()
        }
    }

    func reconcile(with preference: Bool) -> Bool {
        let currentlyEnabled = isEnabled
        if currentlyEnabled != preference {
            apply(preference)
        }
        return isEnabled
    }
}

import Foundation
import Observation
import ServiceManagement

/// Start at login through SMAppService. Failures are shown in Settings and never crash the app.
@Observable
@MainActor
final class LoginItem {
    static let shared = LoginItem()
    private static let configuredKey = "loginItemConfigured"

    private(set) var isOn = SMAppService.mainApp.status == .enabled
    private(set) var needsApproval = SMAppService.mainApp.status == .requiresApproval
    var errorMessage: String?

    func refresh() {
        let status = SMAppService.mainApp.status
        isOn = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// On the very first launch, turn it on once; after that the user's choice in Settings stands.
    func configureOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.configuredKey) == nil else { refresh(); return }
        defaults.set(true, forKey: Self.configuredKey)
        set(true)
    }
}

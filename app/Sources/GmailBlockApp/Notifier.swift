import AppKit
import UserNotifications

/// Shows Mail-block results as the app's own notifications. If macOS does not let the app
/// post notifications, results fall back to a small alert so a click is never silent.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Asks once (macOS remembers the answer) and makes banners show even while the app is in front.
    func prepare() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// `important` results fall back to an alert when banners are off; progress notices do not.
    func post(_ title: String, _ body: String, important: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        // Provisional or alert style None would post without showing anything, so those use the alert.
        if settings.authorizationStatus == .authorized && settings.alertSetting == .enabled {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            if (try? await center.add(request)) != nil { return }
        }
        guard important else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

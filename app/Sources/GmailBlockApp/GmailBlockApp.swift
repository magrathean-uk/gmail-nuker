import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = BlockViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchedAtLogin = Self.wasLaunchedAsLoginItem()
        LoginItem.shared.configureOnFirstLaunch()
        MailBlocker.registerHotKey()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowsChanged(_:)), name: NSWindow.willCloseNotification, object: nil)
        center.addObserver(self, selector: #selector(windowsChanged(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
        if launchedAtLogin {
            // Live in the menu bar quietly; the window opens from the menu.
            DispatchQueue.main.async {
                for window in NSApp.windows where window.canBecomeMain { window.close() }
                self.updatePolicy(closing: nil)
            }
        }
    }

    private static func wasLaunchedAsLoginItem() -> Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    @objc private func windowsChanged(_ note: Notification) {
        let closing = note.name == NSWindow.willCloseNotification ? note.object as? NSWindow : nil
        DispatchQueue.main.async { self.updatePolicy(closing: closing) }
    }

    /// Dock icon only while a real window is open.
    private func updatePolicy(closing: NSWindow?) {
        let hasWindow = NSApp.windows.contains {
            $0 !== closing && $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) && $0.level == .normal
        }
        let wanted: NSApplication.ActivationPolicy = hasWindow ? .regular : .accessory
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if viewModel.isBusy || MailState.shared.running {
            NSSound.beep()
            return .terminateCancel
        }
        return .terminateNow
    }
}

@main
struct GmailBlockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        let viewModel = delegate.viewModel
        Window("Gmail Nuker", id: "main") {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(width: 600, height: 560)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Target") { viewModel.reset() }
                    .keyboardShortcut("n").disabled(viewModel.isBusy)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Gmail Nuker") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q").disabled(viewModel.isBusy || MailState.shared.running)
            }
        }
        Settings { AccountSettingsView(viewModel: viewModel) }
        MenuBarExtra("Gmail Nuker", systemImage: "envelope.badge.shield.half.filled") {
            MenuContent(viewModel: viewModel)
        }
    }
}

struct MenuContent: View {
    let viewModel: BlockViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open Gmail Nuker") { show(nil) }
        Button("Block Sender of Selected Mail Message") { MailBlocker.blockSelected() }
            .keyboardShortcut("b", modifiers: [.control, .option, .command])
        Divider()
        Button("Offender List") { show(.offenders) }
        Button("Blocked Senders") { show(.blocked) }
        Divider()
        Button("Settings…") {
            bringForward()
            openSettings()
        }
        Divider()
        Button("Quit Gmail Nuker") { NSApplication.shared.terminate(nil) }
            .disabled(viewModel.isBusy || MailState.shared.running)
    }

    private func show(_ section: AppSection?) {
        if let section { viewModel.section = section }
        bringForward()
        openWindow(id: "main")
    }

    private func bringForward() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
}

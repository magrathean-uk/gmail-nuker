import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: BlockViewModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if viewModel?.isBusy == true {
            NSSound.beep()
            return .terminateCancel
        }
        return .terminateNow
    }
}

@main
struct GmailBlockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var viewModel = BlockViewModel()

    var body: some Scene {
        Window("Gmail Nuker", id: "main") {
            ContentView(viewModel: viewModel)
                .onAppear { delegate.viewModel = viewModel }
        }
        .defaultSize(width: 560, height: 490)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Target") { viewModel.reset() }
                    .keyboardShortcut("n").disabled(viewModel.isBusy)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Gmail Nuker") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q").disabled(viewModel.isBusy)
            }
        }
        Settings { AccountSettingsView(viewModel: viewModel) }
    }
}

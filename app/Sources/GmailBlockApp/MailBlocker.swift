import AppKit
import Carbon.HIToolbox

/// Block the sender of the message selected in Mail, via the bundled block-sender.sh
/// (exact sender, existing mail to Trash only, notification when done).
@MainActor
enum MailBlocker {
    private static var running = false
    private static var hotKey: EventHotKeyRef?

    /// Control-Option-Command-B. Carbon hot keys need no Accessibility permission.
    static func registerHotKey() {
        guard hotKey == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in MailBlocker.blockSelected() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x474D_4E4B), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKey)
    }

    static func blockSelected() {
        guard !running else { return }
        running = true
        Task {
            await perform()
            running = false
        }
    }

    private static func perform() async {
        let mail = "com.apple.mail"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: mail).isEmpty else {
            await Task.detached { MailWork.notify("Select a message in Mail first.") }.value
            return
        }
        let senders = await Task.detached { MailWork.selectedSenders() }.value
        switch senders {
        case .failure(let error):
            await Task.detached { MailWork.notify(error.message) }.value
        case .success(let list) where list.isEmpty:
            await Task.detached { MailWork.notify("Select a message in Mail first.") }.value
        case .success(let list):
            for sender in list { await Task.detached { MailWork.block(sender) }.value }
        }
    }
}

private struct MailError: Error, Sendable { let message: String }

/// Blocking work (AppleScript, subprocesses); always called off the main actor.
private enum MailWork {
    static func notify(_ message: String, title: String = "Block sender") {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "on run a", "-e", "display notification (item 2 of a) with title (item 1 of a)", "-e", "end run", title, message]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    static func selectedSenders() -> Result<[String], MailError> {
        let source = """
        tell application "Mail"
            set out to {}
            repeat with m in (selection)
                set end of out to (sender of m)
            end repeat
            return out
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return .failure(MailError(message: "Could not read Mail.")) }
        var failure: NSDictionary?
        let descriptor = script.executeAndReturnError(&failure)
        if let failure {
            let code = failure[NSAppleScript.errorNumber] as? Int
            return .failure(MailError(message: code == -1743
                ? "Allow Gmail Nuker to control Mail in System Settings, Privacy & Security, Automation."
                : "Could not read the selected message in Mail."))
        }
        var senders: [String] = []
        if descriptor.numberOfItems > 0 {
            for index in 1...descriptor.numberOfItems {
                if let value = descriptor.atIndex(index)?.stringValue { senders.append(value) }
            }
        } else if let value = descriptor.stringValue {
            senders.append(value)
        }
        var seen = Set<String>()
        return .success(senders.filter { !$0.isEmpty && seen.insert($0).inserted })
    }

    static func block(_ sender: String) {
        guard let script = Bundle.main.url(forResource: "block-sender", withExtension: "sh") else {
            notify("The block script is missing from the app.")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, sender]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() }
        catch { notify("Could not start the block script.") }
    }
}

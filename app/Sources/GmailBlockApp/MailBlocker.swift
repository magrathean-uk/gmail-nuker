import AppKit
import Carbon.HIToolbox
import Observation

/// Block the sender of the message selected in Mail, via the bundled block-sender.sh
/// (exact sender, existing mail to Trash only, notification when done).
/// Observable so the Quit menu items and the quit guard can see a Mail block in progress.
@Observable
@MainActor
final class MailState {
    static let shared = MailState()
    var running = false
}

@MainActor
enum MailBlocker {
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
        guard !MailState.shared.running else { return }
        MailState.shared.running = true
        Task {
            await perform()
            MailState.shared.running = false
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

    /// Reads Mail's selection through /usr/bin/osascript (no sender data is ever put into the script).
    static func selectedSenders() -> Result<[String], MailError> {
        let lines = ["tell application \"Mail\"", "set out to {}", "repeat with m in (selection)",
                     "set end of out to (sender of m)", "end repeat", "set AppleScript's text item delimiters to linefeed",
                     "return out as text", "end tell"]
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = lines.flatMap { ["-e", $0] }
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        guard (try? process.run()) != nil else { return .failure(MailError(message: "Could not read Mail.")) }
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: timeout)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        timeout.cancel()
        if process.terminationReason == .uncaughtSignal {
            return .failure(MailError(message: "Mail did not answer in time. Try again."))
        }
        guard process.terminationStatus == 0 else {
            return .failure(MailError(message: errorText.contains("-1743")
                ? "Allow Gmail Nuker to control Mail in System Settings, Privacy & Security, Automation."
                : "Could not read the selected message in Mail."))
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        var seen = Set<String>()
        let senders = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return .success(senders)
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

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
        guard !MailState.shared.running else {
            Task { await Notifier.shared.post("Still working", "The previous block is still running. Try again when it finishes.", important: false) }
            return
        }
        MailState.shared.running = true
        Task {
            await perform()
            MailState.shared.running = false
        }
    }

    private static func perform() async {
        let notifier = Notifier.shared
        let mail = "com.apple.mail"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: mail).isEmpty else {
            await notifier.post("Nothing to block", "Open Mail, select a message, then try again.")
            return
        }
        let senders = await Task.detached { MailWork.selectedSenders() }.value
        switch senders {
        case .failure(let error):
            await notifier.post("Block failed", error.message)
        case .success(let list) where list.isEmpty:
            await notifier.post("Nothing to block", "Select a message in Mail, then try again.")
        case .success(let list):
            for sender in list {
                await notifier.post("Blocking sender", "\(sender). This can take a minute.", important: false)
                switch await Task.detached(operation: { MailWork.block(sender) }).value {
                case .success(let done):
                    let moved = done.moved == 1 ? "1 message" : "\(done.moved) messages"
                    await notifier.post("Blocked \(done.address)", "Future mail from this sender goes to Trash. \(moved) moved to Trash.")
                case .failure(let error):
                    await notifier.post("Block failed for \(sender)", error.message)
                }
            }
        }
    }
}

private struct MailError: Error, Sendable { let message: String }

/// Blocking work (AppleScript, subprocesses); always called off the main actor.
private enum MailWork {
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

    /// Runs the bundled block-sender.sh with its own notifications off; the app reports the result.
    static func block(_ sender: String) -> Result<MailBlockResult, MailError> {
        guard let script = Bundle.main.url(forResource: "block-sender", withExtension: "sh") else {
            return .failure(MailError(message: "The block script is missing from the app. Reinstall Gmail Nuker."))
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, sender]
        var environment = ProcessInfo.processInfo.environment
        environment["GMAIL_NUKER_NO_NOTIFY"] = "1"
        process.environment = environment
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        guard (try? process.run()) != nil else { return .failure(MailError(message: "Could not start the block script.")) }
        // Drain stderr alongside stdout so neither pipe can fill and stall the script.
        let group = DispatchGroup()
        nonisolated(unsafe) var errorText = Data()
        group.enter()
        DispatchQueue.global().async { errorText = errors.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        let outText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        group.wait()
        process.waitUntilExit()
        if process.terminationStatus == 0, let result = MailBlockResult.parse(outText) { return .success(result) }
        let message = (String(data: errorText, encoding: .utf8) ?? "")
            .split(whereSeparator: \.isNewline).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        return .failure(MailError(message: message.isEmpty ? "The block did not finish. Check Settings and try again." : message))
    }
}

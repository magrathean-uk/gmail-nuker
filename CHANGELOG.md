# Changelog

## Unreleased

- App: the Mail block command now always gives feedback. The menu bar icon shows an hourglass while it runs, and the app posts its own notification on start, success (address and how many messages went to Trash) and failure (what to do). If notifications are off for the app, results show in an alert. Previously results went through `osascript` notifications, which macOS can drop silently.
- App: three sections (Block, Offender list, Blocked). Blocking now covers the whole matching history (up to 5,000 messages) and the confirmation states the real total. The Offender list scans the last 30 days of inbox, blocks several selected senders exactly and deletes after one combined confirmation. The Blocked list searches the tool's filters and unblocks one (mail is never restored).
- App: menu bar icon, open at login (first launch enables it; Settings toggles it), the Dock icon only while a window is open, and a built-in Mail command (Control-Option-Command-B or menu item) that blocks the selected sender and trashes their existing mail via the bundled script. Adds `NSAppleEventsUsageDescription`.

- Add a choice of where the Google key lives: the macOS login Keychain (new default, no prompts) or 1Password. Settings can import a JSON file, copy from 1Password or remove the key; the CLI accepts `--sa keychain`. The Keychain item is readable by processes running as the user while the keychain is unlocked; 1Password still asks each time.
- Add a Mail.app integration (`scripts/mail-integration/`) that blocks the selected sender via the installed app, now bundled in the app and Keychain-aware.

- Update the packaged Python runtime to cryptography 50.0.2 and certifi 2026.10.19.

- Add local Apple silicon app/ZIP packaging with a bundled engine/runtime and official 1Password helper. Retrieve keys only into process memory; add account Settings and a read-only connection check. Simplify the native UI, enable window resizing and keyboard shortcuts, drain subprocess output concurrently, and preserve deletion previews on failure.

- Make the macOS wipe permanently delete the confirmed preview messages, including mail in Trash/Spam. Add irreversible-deletion confirmation, sender/ID checks, full-mail authorization without fallback, and per-message removal verification. Add a separate CLI delete command and synthetic boundary tests. Future incoming mail still goes to Trash.
- Reject failed engine responses and nonzero engine exits in the macOS app instead of showing a successful block. Add synthetic subprocess regression checks.
- Add setup, CLI, architecture, operational recovery, development, and limitations documentation.
- Add software licence, terms, privacy notice, third-party notice, security policy, and community guidance.
- Remove an installation-specific OAuth client identifier from a CLI diagnostic.

## Initial public source — 30 September 2026

- Publish the Python Gmail filter engine and SwiftUI macOS application on main.
- Exclude local credentials and compiled application bundles; use configurable credential paths and mailbox settings.

No packaged release or signed/notarised application is published by these entries.

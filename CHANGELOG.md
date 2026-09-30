# Changelog

## Unreleased

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

# Architecture

The repository contains two front ends to the same Python engine.

- gmail-block is a shell launcher for bin/gmail-block.
- The Python engine parses a target, signs a delegated service-account assertion, obtains a Google access token, reads filters and message metadata, and optionally performs changes.
- The SwiftUI app collects a target and calls BlockService, which starts the engine as a subprocess with block --json --commit --include-spam-trash. After confirmation, its wipe uses the separate delete command with the preview's fixed message IDs. BlockViewModel handles the block, prior-mail prompt, permanent deletion, and result states.
- run.sh opens a colocated app bundle when present or starts the Swift release executable.

Authentication first requests the full configured scope bundle and can retry the base bundle without modify access. Message metadata is fetched individually for the first search page. MX and RDAP lookups inform contact suggestions, not authoritative attribution. Committed operations can unsubscribe, create a filter, purge selected messages, reread state, and send a complaint.

Messages included from Trash/Spam for the deletion preview are excluded from automatic unsubscribe attempts during the block step.

Committed permanent deletion adds full mail scope with no fallback. Every selected ID's From header is checked against the confirmed sender/domain before batchDelete. The engine rereads every selected ID and requires HTTP 404 to verify absence. A failure, mismatched sender, or incomplete verification prevents a success result. The delete command does not rerun blocking, unsubscribe, DNS/RDAP, or IMAP operations and does not pick up newly arrived messages outside the confirmed preview.

There is no publisher-operated server or persistent mailbox database. CLI credentials remain operator-provided files. The packaged app invokes app/engine_launcher.py as a standalone executable, reads the 1Password field into memory, supplies that credential directly to engine authentication, and signs with bundled cryptography. Its nonsecret account configuration and Settings preferences identify the mailbox and vault field. Tokens and results pass through local process memory; stdout/stderr are drained concurrently by the GUI. The separate CLI OpenSSL fallback uses a temporary private-key file. See [PRIVACY.md](../PRIVACY.md) for all external recipients.

## Source map

| File | Responsibility |
| --- | --- |
| bin/gmail-block | Matching, auth, Gmail API, DNS/RDAP, unsubscribe, IMAP, complaints, CLI |
| app/Sources/GmailBlockApp/BlockService.swift | Python subprocess and JSON decode |
| app/Sources/GmailBlockApp/BlockViewModel.swift | GUI operation state |
| app/Sources/GmailBlockApp/ContentView.swift | SwiftUI screens |
| app/Sources/GmailBlockApp/Models.swift | Result decoding |
| app/Package.swift | Swift build definition |
| app/engine_launcher.py | In-memory 1Password and packaged engine bridge |
| app/Sources/GmailBlockApp/AccountConfiguration.swift | Nonsecret account configuration and preferences |
| scripts/package-app.py | Local app and ZIP builder |
| scripts/make-icon.swift | AppKit app-icon renderer |

The GUI has account Settings and a 1Password credential bridge, but no dry-run mode, exact-match control, or abuse-report control. Its initial action commits immediately; the subsequent confirmation controls permanent deletion of the listed messages.

# Architecture

The repository contains two front ends to the same Python engine.

- gmail-block is a shell launcher for bin/gmail-block.
- The Python engine parses a target, signs a delegated service-account assertion, obtains a Google access token, reads filters and message metadata, and optionally performs changes.
- The SwiftUI app collects a target and calls BlockService, which starts the engine as a subprocess with block --json --commit. BlockViewModel handles the block, prior-mail prompt, purge, and result states.
- run.sh opens a colocated app bundle when present or starts the Swift release executable.

Authentication first requests the full configured scope bundle and can retry the base bundle without modify access. Message metadata is fetched individually for the first search page. MX and RDAP lookups inform contact suggestions, not authoritative attribution. Committed operations can unsubscribe, create a filter, purge selected messages, reread state, and send a complaint.

There is no publisher-operated server or persistent mailbox database. Credentials remain operator-provided files. Tokens and results pass through local process memory; stdout/stderr are captured by the GUI or terminal. OpenSSL fallback uses a temporary private-key file. See [PRIVACY.md](../PRIVACY.md) for all external recipients.

## Source map

| File | Responsibility |
| --- | --- |
| bin/gmail-block | Matching, auth, Gmail API, DNS/RDAP, unsubscribe, IMAP, complaints, CLI |
| app/Sources/GmailBlockApp/BlockService.swift | Python subprocess and JSON decode |
| app/Sources/GmailBlockApp/BlockViewModel.swift | GUI operation state |
| app/Sources/GmailBlockApp/ContentView.swift | SwiftUI screens |
| app/Sources/GmailBlockApp/Models.swift | Result decoding |
| app/Package.swift | Swift build definition |

The GUI currently has no account picker, dry-run mode, exact-match control, credential manager, or abuse-report control. Its initial action commits immediately; the subsequent prompt controls prior-message purge.

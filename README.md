# gmail-nuker

A Gmail sender and domain blocker with a Python CLI and a native macOS SwiftUI app.

Creates Gmail filters that send matching messages to Trash and remove Inbox, unread, and important labels. It can optionally trash existing matching mail. Public webmail providers and shared hosting domains receive narrower matching to reduce accidental blocking.

## Configuration

Credentials are deliberately excluded from this repository. Supply your own Google Workspace service account with domain-wide delegation and appropriate Gmail scopes. The current authentication flow uses a delegated service account; ordinary consumer Gmail OAuth setup is not implemented.

```bash
export GMAIL_BLOCK_SA="/absolute/path/to/service-account.json"
export GMAIL_BLOCK_USER="you@example.com"
# Optional SMTP/IMAP fallback credential file:
export GMAIL_SMTP_CREDS="/absolute/path/to/gmail-smtp.md"
```

Alternatively, local credential files can live in the ignored `secrets/` directory. Never commit keys, tokens, passwords, or real credential files.

## CLI

Requires Python 3.14; RSA signing uses the optional `cryptography` package or the `openssl` command.

```bash
./gmail-block --help
./gmail-block spammer@example.com
./gmail-block block spammer@example.com --commit
./gmail-block block spammer@example.com --commit --purge
./gmail-block list
./gmail-block unblock spammer@example.com --commit
```

The default target command analyzes the target and inventories matching mail. `--commit` enables changes. `--purge` moves matching existing mail to Trash. Commit operations can also attempt unsubscribe requests; `--report-abuse` enables abuse emails to discovered contacts. Review the CLI help before using these options.

## macOS app

Requires macOS 14+ and Swift 6.4.

```bash
cd app
swift build -c release
cd ..
./run.sh
```

Launch from the repository root so the app can find `bin/gmail-block`, and provide the configuration variables in its environment. The GUI uses Homebrew Python when available. The compiled app bundle is excluded from source control.

## Source

- `bin/gmail-block`: Python engine
- `gmail-block`: CLI launcher
- `app/Sources/GmailBlockApp`: SwiftUI application
- `run.sh`: application launcher

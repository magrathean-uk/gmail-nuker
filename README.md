# gmail-nuker

A Gmail sender and domain blocker with a Python CLI and a native macOS SwiftUI app.

Creates Gmail filters that send matching messages to Trash and remove Inbox, unread, and important labels. It can also trash existing mail or permanently delete explicitly selected preview messages. The macOS wipe action asks for confirmation, permanently deletes only the listed messages, and verifies removal. Public webmail providers and shared hosting domains receive narrower matching to reduce accidental blocking.

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
./gmail-block block spammer@example.com --json --include-spam-trash
./gmail-block delete spammer@example.com --message-id PREVIEW_MESSAGE_ID
./gmail-block delete spammer@example.com --message-id PREVIEW_MESSAGE_ID --commit
./gmail-block list
./gmail-block unblock spammer@example.com --commit
```

The default target command analyzes the target and inventories matching mail. `--commit` enables changes. `block --purge` moves matching existing mail to Trash. `delete --commit` permanently deletes selected `--message-id` values after checking their senders; without `--commit`, delete is a read-only preview. Permanent deletion requires the delegated `https://mail.google.com/` scope and cannot be recovered from Gmail Trash. Committed blocks can also attempt unsubscribe requests; the separate delete command does not unsubscribe or change filters. `--report-abuse` enables abuse emails to discovered contacts. Review the CLI help before using these options.

## macOS app

Runs on Apple silicon Macs with macOS 14+. Building requires Swift 6.4, `uv`, and the official 1Password CLI.

```bash
python3 scripts/package-app.py
open "dist/Gmail Nuker.app"
```

The app bundles its Python engine/runtime, cryptography, certificate trust store and 1Password helper. It launches from Finder without a checkout or Terminal environment. In Account Settings, enter your Workspace mailbox and the 1Password secret reference for the field containing your service-account JSON. The key is fetched into process memory per operation and is never embedded in the app or archive.

The UI uses standard macOS controls, a resizable window, keyboard shortcuts, a bounded message preview, and a separate permanent-delete confirmation. Settings includes a read-only connection check. Local bundles use ad-hoc signing; this is not a notarised public release. See [setup](docs/setup.md) for personal configuration and packaging details. Compiled apps and archives remain excluded from source control.

## Behavior to review

Committed blocks may automatically contact unsubscribe endpoints or send unsubscribe email. CLI `block --purge` moves messages to Trash; IMAP fallback issues Deleted/expunge operations. The GUI previews Spam and Trash too and confirms permanent deletion of the listed IDs. Permanent deletion has no IMAP or Trash fallback. Scans fetch one page, default 50 and at most 500 IDs, rather than every historical message. Review [limitations](docs/limitations.md) before changing a mailbox.

## Documentation

- [Setup and Google Workspace permissions](docs/setup.md)
- [CLI commands and flags](docs/cli.md)
- [Architecture and source map](docs/architecture.md)
- [Operations, recovery, and credential rotation](docs/operations.md)
- [Current limitations](docs/limitations.md)
- [Development and verification](docs/development.md)
- [Contributing](CONTRIBUTING.md), [code of conduct](CODE_OF_CONDUCT.md), and [support](SUPPORT.md)
- [Security reporting](SECURITY.md), [privacy](PRIVACY.md), [software terms](TERMS.md), [licence](LICENSE), and [third-party notice](NOTICE)
- [Changelog](CHANGELOG.md)

## Source

- `bin/gmail-block`: Python engine
- `gmail-block`: CLI launcher
- `app/Sources/GmailBlockApp`: SwiftUI application
- `run.sh`: application launcher

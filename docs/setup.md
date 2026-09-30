# Setup

## Requirements

Use Python 3.14 for the CLI. RSA signing uses optional `cryptography`; otherwise the engine invokes `openssl` and temporarily writes the private key to disk. MX lookup uses the host's DNS command. The GUI requires macOS 14+ and Swift 6.4. The CLI has not been verified on every operating system.

```bash
git clone https://github.com/magrathean-uk/gmail-nuker.git
cd gmail-nuker
python3 --version
./gmail-block --help
```

## Google Workspace authentication

The implemented flow is a service account impersonating a Workspace user through domain-wide delegation. It is not an ordinary consumer Gmail OAuth login. An IMAP fallback does not replace service-account authentication.

1. In your own Google Cloud project, enable the Gmail API and create a service account.
2. Configure domain-wide delegation and obtain a JSON private key. Keep it outside the checkout, or in ignored `secrets/service-account.json`; restrict file access, for example with `chmod 600`.
3. A Workspace super administrator authorises that service account's own numeric client ID and required scopes in the Admin console. Never copy another installation's client ID.
4. Set the delegated mailbox to an authorised user in that Workspace domain.

See Google's [domain-wide delegation instructions](https://developers.google.com/identity/protocols/oauth2/service-account#delegatingauthority) and [Gmail scope reference](https://developers.google.com/workspace/gmail/api/auth/scopes).

The current engine requests these scopes as a bundle:

| Scope suffix | Used for |
| --- | --- |
| gmail.settings.basic | List, create, and delete filters |
| gmail.readonly | Read message metadata |
| gmail.modify | Change message labels for API purge |
| gmail.send | Send mailto unsubscribe requests and optional complaints |

Each suffix is prefixed with `https://www.googleapis.com/auth/`. If the full bundle is rejected with unauthorized_client, the engine retries without gmail.modify. It still requests gmail.send, even for read-only commands. It does not negotiate the least possible scope for each command.

Permanent deletion additionally requires **https://mail.google.com/** in the Workspace delegation. The GUI wipe and CLI `delete --commit` request it explicitly and fail if it is unavailable; they do not fall back to Trash or IMAP. Ordinary block/list commands keep their existing scope bundle.

```bash
export GMAIL_BLOCK_SA="/absolute/path/to/service-account.json"
export GMAIL_BLOCK_USER="you@example.com"
./gmail-block list
```

`list` contacts Google and displays mailbox filters but does not modify them. Defaults are `secrets/service-account.json` and the placeholder `you@example.com`. --sa and --user can override them; see [CLI placement rules](cli.md).

## Optional IMAP fallback

If modify access is unavailable, a committed purge may fall back to `GMAIL_SMTP_CREDS` (default `secrets/gmail-smtp.md`). The parser expects Markdown fields in this form:

```text
**Username**: `you@example.com`
**App Password**: `REPLACE_WITH_YOUR_OWN_APP_PASSWORD`
```

This is a description of the expected format, not a credential file to commit. The username must match the delegated mailbox. IMAP connects to imap.gmail.com over TLS, selects [Gmail]/All Mail, marks matches Deleted, and expunges them. Results depend on account settings and folder naming. This path can affect more messages than the API preview limit; see [limitations](limitations.md).

## Build and launch the app

Building requires macOS, Swift 6.4, `uv`, and the official 1Password CLI. The builder creates an Apple silicon app and ZIP in ignored `dist/`. It bundles Python 3.14, cryptography, certifi, and a copy of the installed 1Password CLI with its vendor signature preserved. The current package was tested on macOS 26.7.1; macOS 14 is its deployment target, not a verified test platform.

```bash
python3 scripts/package-app.py
open "dist/Gmail Nuker.app"
```

Open Account Settings, enter the delegated Workspace address and an `op://Vault/Item/credential` secret reference. The field must contain the complete service-account JSON. Enable **1Password Settings → Developer → Integrate with 1Password CLI**, keep 1Password installed, and approve its access request. **Save & Check Connection** reads the Gmail profile without creating filters, deleting messages, sending, or unsubscribing.

For a personal preconfigured build, create a nonsecret JSON file outside the checkout and pass `--config /path/to/account.json`. It contains only `mailbox`, `secretReference`, and `serviceAccount` strings. An optional `opConfigDirectory` preserves an existing custom 1Password CLI configuration directory; `~` is expanded at runtime. Never put the private-key JSON into this configuration. A personal bundle may identify your mailbox and vault item, so review it before sharing.

The app and ZIP contain no service-account key. The bridge fetches it from 1Password into memory for each operation, signs in memory using bundled cryptography, and exits when that operation completes. The package does not use the plaintext IMAP fallback. Native Settings stores only the mailbox and field reference in macOS preferences. Quit is disabled during an active operation so closing the application does not interrupt a permanent deletion.

The initial **Block** action commits a filter and can attempt unsubscribe requests. It then previews up to 50 messages, including Spam and Trash. **Delete Permanently…** requires a separate confirmation and acts only on that preview. A deletion failure retains the preview and active block so the same IDs can be retried.

These are local ad-hoc signed bundles, without Developer ID notarisation, automated updates, or an App Store distribution. The CLI remains available independently. A raw `swift build -c release` executable is useful for source/UI development and keeps its external engine/file-credential fallback; Finder use and built-in 1Password access require the packaged app.

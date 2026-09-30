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

```bash
cd app
swift build -c release
cd ..
./run.sh
```

Run from the checkout root with configuration exported in the launching shell. When no app bundle exists, run.sh launches app/.build/release/GmailBlockApp. The app first checks for bin/gmail-block beside a bundle, then under its working directory. Homebrew Python at /opt/homebrew/bin/python3 is preferred; otherwise the executable's env python3 uses the available PATH.

The repository provides source, not a signed/notarised app installer. Configuration is not an interactive GUI login. The GUI submits committed blocks immediately and asks separately whether to purge prior mail.

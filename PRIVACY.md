# Privacy notice

Effective date: 30 September 2026.

This notice describes the CLI and macOS source in gmail-nuker, maintained by MAGRATHEAN UK LTD. The software runs on your device and communicates directly with the services described below. It has no publisher-operated mailbox backend, analytics, advertising, or telemetry endpoint.

## Information processed locally

The tool reads a service-account JSON key, the delegated mailbox address, target addresses or domains, and Gmail filter and message metadata. Metadata includes message and thread identifiers, From, Subject, Date, List-Unsubscribe, and List-Unsubscribe-Post headers. These fields can contain personal data and unique tracking URLs. The current mailbox scan requests metadata rather than full message bodies.

Access tokens and signed assertions are used in process memory. If the optional cryptography package is unavailable, the OpenSSL signing fallback writes the private key to a temporary file that is scheduled for deletion when the context closes. This is not Keychain storage and is not a guarantee of secure erasure after a crash. Optional IMAP fallback reads a local plaintext app-password file.

CLI output, JSON results, errors, terminal history, and GUI state can reveal targets, subjects, mailbox addresses, identifiers, credential paths, or remote error responses. The tool does not maintain a separate persistent mailbox database. Redirected output, credentials, backups, operating-system diagnostics, and terminal logs remain under your control.

## Network recipients and purposes

| Recipient | Information and purpose |
| --- | --- |
| Google OAuth and Gmail APIs | Signed service-account assertion and delegated user for authentication; authorized filter queries, message metadata, filter changes, trash operations, and email sending |
| Local DNS resolver | Target-domain MX queries to identify incoming mail infrastructure |
| rdap.org and redirected registration services | Target domain and ordinary connection metadata for registrar/contact lookup |
| Sender-provided unsubscribe endpoints | URL, potentially including recipient identifiers, and one-click POST when a committed block finds a suitable header |
| Unsubscribe email recipient | Your sending address and unsubscribe request through Gmail when mailto fallback is selected |
| Abuse-report recipients | Your mailbox address, target/domain, a sample subject, and generated complaint when --commit --report-abuse is used |
| GitHub | Repository access and any information you voluntarily submit in issues or pull requests |

A dry-run block still authenticates, reads Gmail metadata, and performs DNS/RDAP requests. A committed block may initiate unsubscribe traffic automatically, including when an equivalent block filter already exists. There is no separate unsubscribe opt-in switch. The generated Safe Browsing link contacts that service only if opened. Providers apply their own policies, retention, and international-transfer arrangements.

## Retention and controls

Gmail filters remain until removed. API purge labels messages as Trash rather than requesting immediate permanent deletion. Gmail and administrator retention settings govern subsequent retention; IMAP fallback uses Deleted/expunge and may behave differently. Unblocking does not restore messages or undo unsubscribe requests and reports already sent.

Remove local credentials and saved output when no longer needed; revoke service-account keys, delegation grants, and app passwords through Google as appropriate. Removing this checkout alone does not revoke credentials or delete remote filters. See [operations](docs/operations.md).

## Information voluntarily sent to the maintainer

Mailbox data is not sent to MAGRATHEAN UK LTD by the application. If you contact us for support, licensing, conduct, or security, we receive the correspondence and material you choose to share. We use that material to respond, investigate, administer the project, and protect it; retain it only as needed for those purposes or applicable obligations; and do not request live credentials or full mailboxes. GitHub public submissions are visible to others and may remain in Git history or platform records.

For personal information processed by the maintainer through those communications, MAGRATHEAN UK LTD is the relevant controller. The operator of a business or shared mailbox remains responsible for its own use of the tool and the data it processes. This repository does not provide a data-processing agreement or a hosted mailbox service.

## Questions and rights

Contact [contact@magrathean.uk](mailto:contact@magrathean.uk), subject `PRIVACY: gmail-nuker`, for privacy questions or requests concerning information held by the maintainer. Applicable data-protection rights depend on the processing and jurisdiction; direct requests concerning Google-held mailbox data to Google or your Workspace administrator. UK users can consult the [ICO guidance](https://ico.org.uk/for-the-public/) and [complaints route](https://ico.org.uk/make-a-complaint/). Changes to this notice will be recorded here with a new effective date.

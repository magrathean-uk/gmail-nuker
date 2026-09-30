# Software terms

Effective date: 30 September 2026.

The software licence in [LICENSE](LICENSE) governs permission to use and redistribute gmail-nuker. These terms explain operation, responsibilities, and third-party boundaries; they do not create a paid subscription or hosted-service agreement, or override the licence.

## Account authority and operation

Operate only mailboxes you own or are authorised to administer. Workspace delegation can grant broad account access. You are responsible for obtaining the required authority, configuring scopes and credentials, and meeting your organisation's records, privacy, and retention requirements.

Review the mailbox and target before committing. A custom-domain target normally expands to a root-domain filter, which can affect legitimate correspondence. Committed blocks can automatically send unsubscribe requests. Purge changes existing mail; IMAP fallback issues Deleted/expunge operations. These actions are not fully reversible. Keep independent copies of mail you need and review [documented limitations](docs/limitations.md).

## Reports and third parties

Abuse reports are generated from limited metadata and contact discovery. You are responsible for checking the facts and recipients before sending. The generated complaint contains allegations about consent, prior unsubscribe attempts, and continuing unsolicited messages that the software cannot verify. MX and RDAP results do not establish who sent a message or whether conduct is unlawful. The tool does not provide legal advice or a legal determination of spam, phishing, or abuse.

Google, GitHub, registries, email recipients, and other services have their own terms and policies. Gmail is a Google trademark. This project is independent of Google and is not endorsed by it. Provider availability, API compatibility, delivery, recovery, and retention are outside the maintainer's control.

## Warranty, liability, and support

The warranty and liability provisions are in [LICENSE](LICENSE), subject to applicable law. No guaranteed blocking accuracy, complete mailbox cleanup, security certification, service level, or response time is offered. Nothing here excludes rights or liability that applicable law does not allow to be excluded.

See [PRIVACY.md](PRIVACY.md), [SUPPORT.md](SUPPORT.md), and [SECURITY.md](SECURITY.md). Licensing and general enquiries: [contact@magrathean.uk](mailto:contact@magrathean.uk).

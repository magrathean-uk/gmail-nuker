# Security policy

## Supported code

Security fixes target the latest main branch. There are no versioned release-support commitments yet. This policy is not a security audit or a claim that the software is safe for every mailbox.

## Private reporting

Do not post vulnerabilities, credentials, mailbox contents, or exploit details in public issues. Email [contact@magrathean.uk](mailto:contact@magrathean.uk) with subject `SECURITY: gmail-nuker`, following the [organisation policy](https://github.com/magrathean-uk/.github/blob/main/SECURITY.md). GitHub private vulnerability reporting was disabled when checked on 30 September 2026; use email as the current route.

Include the commit, platform, command or affected component, expected and actual behavior, impact, and a reproduction using synthetic data. Never send a real private key, access token, app password, full mailbox, or customer data. No bounty or guaranteed response time is offered.

## Security-sensitive boundaries

Report realistic credential disclosure, unsafe handling of sender-controlled unsubscribe URLs, shell or argument injection, mailbox changes beyond documented target/commit controls, unexpected sending, and compromised distribution or dependencies.

Mail headers, domains, MX records, and RDAP responses are untrusted inputs. The service-account key and delegation grants may allow access beyond the mailbox used in a command. Keep keys outside Git and restrict their local permissions. .gitignore reduces accidental inclusion; it does not protect already tracked files or act as a secret scanner.

## Current limitations

Committed block operations automatically process unsubscribe headers. Their URLs may be attacker-controlled and may identify the recipient; the client can follow redirects. Run only in an environment where these requests are acceptable. The tool is not a network sandbox.

The OpenSSL fallback temporarily writes a private key to disk. IMAP fallback reads plaintext app-password credentials and expunges messages. Domain matching uses maintained lists and a suffix heuristic rather than a complete current Public Suffix List. The GUI and CLI can show optimistic success despite partial failures. See [limitations](docs/limitations.md) and [privacy](PRIVACY.md).

For accidental credential exposure, revoke the affected key or app password and delegation as appropriate before cleaning public history. Deleting the file in a later commit does not remove it from earlier commits or clones.

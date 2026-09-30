# Current limitations

These limitations describe the source at the initial public release and documentation update, not a completed security audit.

- Consumer Gmail OAuth login is not implemented. Service-account delegation requires an authorised Workspace environment; optional IMAP fallback only applies after service-account authentication.
- Domain expansion uses embedded provider/suffix lists and heuristics, not a complete live Public Suffix List. Gmail from matching is provider-defined and is not proof of domain ownership or sender authentication.
- Mail inventory reads a single Gmail search page, default 50 and at most 500 IDs. It does not follow pagination. Failed metadata reads can produce blank header entries.
- API purge operates on fetched IDs. IMAP fallback performs its own FROM search of All Mail, can affect more mail than the preview, and may broaden a shared-platform target to the root domain. It assumes English Gmail folder naming and uses Deleted/expunge.
- Future incoming mail and CLI block --purge use Trash. The GUI wipe and CLI delete --commit permanently delete only selected preview IDs and verify absence; they do not claim all historical messages or provider-retained copies were erased. Some older engine wording overstates Trash behavior. Matching and provider retention remain subject to Gmail behavior.
- --commit can automatically contact sender-controlled unsubscribe URLs or send an unsubscribe email. There is no independent opt-out flag, and redirects may be followed.
- MX identifies incoming mail routing, not necessarily the outbound sender or an appropriate abuse desk. RDAP contact availability and accuracy vary. Generated complaints include factual allegations the tool has not verified and cannot be reviewed as a complete email in a separate built-in draft step.
- The ordinary scope bundle includes gmail.send even for read-only commands; it falls back only by removing gmail.modify. Permanent deletion additionally requests https://mail.google.com/ and has no reduced-scope fallback.
- --json is implemented for block and delete; other commands accept but do not implement structured output. Leading global options conflict with shorthand dispatch.
- Block JSON can return success after partial purge or report failures. Some warnings go only to stderr, and the GUI does not independently establish complete mailbox cleanup or interpret every failure.
- The GUI rejects explicit success:false engine responses and nonzero engine exits, including authentication failures. This does not resolve the partial-success cases described above.
- The GUI commits its first block immediately. Its later wipe requires a separate permanent-deletion confirmation and uses only the preview IDs, without repeating unsubscribe or blocking. The preview includes Spam and Trash but remains limited to 50 messages. It does not expose CLI exact or force-domain controls.
- GUI subprocess streams are drained concurrently; subprocesses still rely on provider timeouts. 1Password approval has a 120-second timeout. Quit is disabled during operations; this does not protect against forced termination or system shutdown.
- CLI OpenSSL fallback temporarily writes a private key to disk. The packaged 1Password bridge signs in memory and does not use plaintext IMAP fallback. Credentials are not stored in the app or Keychain by this application; Settings persists only nonsecret mailbox/field-reference preferences.
- Local Apple silicon app/ZIP packaging is provided with ad-hoc signing. Developer ID notarisation, automated updates, cross-platform validation, and a stable versioned JSON schema are not provided. The built app was tested on macOS 26.7.1; other supported deployment versions remain unverified.

Report reproducible issues through [support](../SUPPORT.md), or use [private security reporting](../SECURITY.md) for vulnerabilities.

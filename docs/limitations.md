# Current limitations

These limitations describe the source at the initial public release and documentation update, not a completed security audit.

- Consumer Gmail OAuth login is not implemented. Service-account delegation requires an authorised Workspace environment; optional IMAP fallback only applies after service-account authentication.
- Domain expansion uses embedded provider/suffix lists and heuristics, not a complete live Public Suffix List. Gmail from matching is provider-defined and is not proof of domain ownership or sender authentication.
- Mail inventory reads a single Gmail search page, default 50 and at most 500 IDs. It does not follow pagination. Failed metadata reads can produce blank header entries.
- API purge operates on fetched IDs. IMAP fallback performs its own FROM search of All Mail, can affect more mail than the preview, and may broaden a shared-platform target to the root domain. It assumes English Gmail folder naming and uses Deleted/expunge.
- The code's words wipe, incinerate, permanently purged, and completely blocked overstate the guarantee. Gmail API operations label messages as Trash and matching is subject to Gmail behavior. Retention and recovery are provider-controlled.
- --commit can automatically contact sender-controlled unsubscribe URLs or send an unsubscribe email. There is no independent opt-out flag, and redirects may be followed.
- MX identifies incoming mail routing, not necessarily the outbound sender or an appropriate abuse desk. RDAP contact availability and accuracy vary. Generated complaints include factual allegations the tool has not verified and cannot be reviewed as a complete email in a separate built-in draft step.
- The scope bundle includes gmail.send even for read-only commands; it falls back only by removing gmail.modify.
- --json is reliable as an intended format only for block; other commands accept but do not implement structured output. Leading global options conflict with shorthand dispatch.
- Block JSON can return success after partial purge or report failures. Some warnings go only to stderr, and the GUI does not independently establish complete mailbox cleanup or interpret every failure.
- The GUI commits its first block immediately and its prior-message purge runs a second committed block. This can repeat an unsubscribe attempt. It does not expose CLI exact or force-domain controls.
- GUI subprocess pipes are read after waitUntilExit; sufficiently large output can block the child. Avoid large GUI inventories until process-output handling is improved.
- OpenSSL fallback temporarily writes a private key to disk. Credential files and optional app passwords are not stored by the app in Keychain.
- Source build is provided; signed/notarised installers, automated updates, cross-platform validation, and a stable versioned JSON schema are not provided.

Report reproducible issues through [support](../SUPPORT.md), or use [private security reporting](../SECURITY.md) for vulnerabilities.

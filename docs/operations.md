# Operation and recovery

## Before applying a block

Confirm the delegated mailbox, keep independent copies of messages you need, and preview the target with block without --commit. Review the resulting match mode, root domain, filter criteria, and sample headers. The preview still contacts Google, DNS, and RDAP services.

Use --exact when blocking only a custom-domain sender is intended. Be cautious with --force-domain. If unsubscribe traffic is unacceptable for a suspicious sender, the current committed flow is unsuitable without a code change; use Gmail's own filter interface instead.

## After a change

List filters and check the Gmail settings interface. Inspect Trash and Inbox with a representative message. If purging, repeat a read-only scan with an appropriate limit and review Gmail search directly. A zero-result scan or success banner is bounded evidence, not proof that all historical messages were removed. Pagination and errors can hide work; see [limitations](limitations.md).

For complaints, review the generated wording and discovered recipients before using --report-abuse. There is no separate preview/send workflow for the final generated email. The implementation cannot verify its allegations or attribute the sending infrastructure from MX records.

## Permanently delete previous mail

The GUI includes Trash and Spam in its bounded preview. Choose Delete Permanently, review the confirmation's target and count, then confirm. Only the listed IDs are deleted. Incoming mail continues to be routed to Trash; the filter does not automatically permanently delete future arrivals.

For CLI use, get IDs from a JSON block preview with `--include-spam-trash`, then run `delete TARGET --message-id ID` (repeat the flag per selected ID). This is read-only until `--commit` is added. Use the same `--exact` or `--force-domain` mode as the reviewed preview. The committed command checks senders before deletion and verifies selected IDs are absent afterward. It has no unsubscribe or IMAP fallback.

Permanent deletion cannot be undone from Gmail Trash. In the GUI, a failed deletion retains the preview and active block so the same IDs can be retried. A failed verification reports an error rather than wipe complete; some selected messages may already have been deleted before a provider error. Rerun a read-only preview to inspect remaining mail. Already absent selected IDs are reported separately from newly deleted messages. The scan limit still applies; the result is not a claim about unlisted historical mail.

## Undo a filter

```bash
./gmail-block unblock sender@example.com
./gmail-block unblock sender@example.com --commit
./gmail-block list
```

Preview which filters will be removed; a target may match more than one filter. You can also delete a selected filter through Gmail settings. Unblocking stops that filter's future operation; it does not restore historical messages, recall mail, cancel delivered reports, or resubscribe you.

## Restore mail

Use Gmail's interface to move recoverable messages out of Trash and apply the desired Inbox/read/important state. Recovery depends on provider and administrator settings, elapsed time, and the operation performed. The CLI has no restoration command. IMAP Deleted/expunge behavior may differ from API Trash label changes; avoid it for records requiring controlled retention.

## Credential rotation and uninstall

Revoke exposed service-account keys and app passwords through Google. Review or remove domain-wide delegation if access is no longer needed. Update local configuration to a replacement key only after authorising it appropriately. Removing the source folder leaves remote Gmail filters intact and does not revoke credentials. Remove filters and revoke access separately.

Do not publish real metadata when asking for help. Follow [SUPPORT.md](../SUPPORT.md) or the private security route.

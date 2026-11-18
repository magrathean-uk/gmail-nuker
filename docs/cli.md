# CLI reference

The executable remains named gmail-block within the gmail-nuker repository.

```bash
./gmail-block --help
./gmail-block block --help
```

## Commands

| Command | Result | Remote writes |
| --- | --- | --- |
| block TARGET | Target analysis, filter/mail inventory, DNS/RDAP lookup | With --commit; may unsubscribe automatically |
| list [--json] | Display active Gmail filters (--json: only from-only filters in this tool's own TRASH+skip-Inbox shape, sorted by sender) | None |
| scan TARGET | Read matching message metadata | None |
| unblock TARGET [--id-only] [--json] | Preview matching filters or supplied filter ID; --id-only matches a filter ID exactly, never by substring, and refuses filters not made by this tool | With --commit, delete selected filters (never touches mail) |
| offenders [--days 30] [--sample 500] [--json] | Rank recent inbox senders by volume, excluding the mailbox owner and senders already blocked | None |
| abuse-info TARGET | MX/RDAP contact lookup and report links | No mail sending; performs network lookups |

Passing a target directly is shorthand for block. Supply --sa and --user after the subcommand: the convenience dispatcher currently misinterprets leading global options as a target invocation. This is a known parser limitation.

```bash
./gmail-block block sender@example.com --sa /path/key.json --user you@example.com
./gmail-block sender@example.com
./gmail-block scan sender@example.com --exact --limit 50
./gmail-block block sender@example.com --exact --commit
./gmail-block block example.com --commit --purge --limit 100
./gmail-block unblock sender@example.com
./gmail-block unblock sender@example.com --commit
./gmail-block abuse-info example.com
```

## Matching and options

--exact narrows an email target to its exact address. Without it, a custom-domain email generally expands to its root domain. Known public webmail providers narrow to the sender; known shared hosting platforms preserve tenant scope. --force-domain overrides those safeguards. Domain parsing is heuristic and does not prove that a sender owns a domain. Preview filter criteria before committing.

scan --limit defaults to 50. block scans the whole matching history by default, following nextPageToken up to 5000 IDs (--limit N caps it lower); JSON reports found_ids, found_total and history_truncated. Metadata is fetched only for the first 50 messages, on at most 8 threads. API purge moves every found ID to Trash in batches of 1000; IMAP fallback searches independently and can be broader. delete accepts up to 5000 IDs, checks every sender before deleting anything, and removes in batches of 1000.

--json is accepted on all subcommands by the parser, but structured JSON is implemented for block. Do not treat other commands' output as a stable JSON API. The macOS application decodes block output.

## Writes and side effects

--commit permits filter changes and automatic unsubscribe attempts. --purge additionally changes existing mail. --report-abuse with --commit sends a generated complaint to discovered contacts (or abuse@target-domain if none are found). The command does not submit a Google phishing report automatically; it prints a link.

Unsubscribe selects the first scanned message with an unsubscribe header and may make a one-click HTTP POST or send an unsubscribe email. It can happen even when a duplicate filter is already active. No separate switch disables it.

Incoming filters add TRASH and remove INBOX, UNREAD, and IMPORTANT. API purge adds TRASH and removes INBOX. These are label changes, not a permanent-delete API call. Filter removal does not restore previously trashed messages.

Output can contain private metadata. --json success and exit status are not proof that every sub-operation succeeded; check filter state and messages as described in [operations](operations.md).

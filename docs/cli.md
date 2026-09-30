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
| list | Display active Gmail filters | None |
| scan TARGET | Read matching message metadata | None |
| unblock TARGET | Preview matching filters or supplied filter ID | With --commit, delete selected filters |
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

--limit defaults to 50 for block and scan. The current Gmail search fetches one page of up to 500 message IDs and does not follow nextPageToken. Raising the limit above 500 does not scan the whole mailbox. API purge affects the fetched message IDs; IMAP fallback searches independently and can be broader.

--json is accepted on all subcommands by the parser, but structured JSON is implemented for block. Do not treat other commands' output as a stable JSON API. The macOS application decodes block output.

## Writes and side effects

--commit permits filter changes and automatic unsubscribe attempts. --purge additionally changes existing mail. --report-abuse with --commit sends a generated complaint to discovered contacts (or abuse@target-domain if none are found). The command does not submit a Google phishing report automatically; it prints a link.

Unsubscribe selects the first scanned message with an unsubscribe header and may make a one-click HTTP POST or send an unsubscribe email. It can happen even when a duplicate filter is already active. No separate switch disables it.

Incoming filters add TRASH and remove INBOX, UNREAD, and IMPORTANT. API purge adds TRASH and removes INBOX. These are label changes, not a permanent-delete API call. Filter removal does not restore previously trashed messages.

Output can contain private metadata. --json success and exit status are not proof that every sub-operation succeeded; check filter state and messages as described in [operations](operations.md).

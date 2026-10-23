# gmail-nuker project context

Gmail-nuker is a Gmail mailbox clean-up tool with a CLI and a GUI. Source builds, source publication and live mailbox operations are separate activities.

## Behaviour and documentation

Mailbox operations include authentication, sending, unsubscribe requests, purge operations and live filter changes. Account selection, deletion targets, network requests, sender-controlled URLs and partial failure handling affect the tool's behaviour.

- `SECURITY.md`: security model and reporting context.
- `docs/limitations.md`: supported behaviour and limitations.
- `docs/development.md`: development commands and checks.
- `NOTICE`: third-party provenance.

The CLI, GUI, privacy, setup and operations documents describe different surfaces of the same implementation. Synthetic fixtures and mocked services exercise source behaviour without establishing live mailbox acceptance. A successful source build does not establish permanent deletion, complete mailbox cleanup, sender attribution or provider endorsement.

## Development environment

The machine's `~/dev/machine/env.zsh` provides routed storage variables. `$TMPDIR` identifies session scratch, `$CLEAN_DEV_BUILDS` identifies throwaway build output, and cache variables identify dependency caches. `.clean-development.json` records repository build and dependency directories.

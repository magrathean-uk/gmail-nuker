# gmail-nuker working guidance

- Preserve the distinction between source publication and authorised mailbox operation. Do not authenticate, send, unsubscribe, purge, or alter live filters without explicit task authority.
- Never read or publish real credential values or mailbox contents for routine source work. Use synthetic fixtures and mocked services. Keep local credential files ignored and outside commits.
- Read SECURITY.md and docs/limitations.md before changing account, target, deletion, network, or sending behavior. Commit controls, scope expansion, sender-controlled URLs, and partial failure handling are security-sensitive.
- Keep CLI, GUI, privacy, setup, operations, and limitations docs consistent with the implementation. Do not claim permanent deletion, complete cleanup, verified attribution, or provider endorsement without evidence.
- Run relevant checks from docs/development.md. Source builds do not prove live mailbox behavior. Record actual verification and remaining gaps.
- Keep changes focused; avoid unrelated refactors and fabricated release claims. Maintain third-party provenance in NOTICE.

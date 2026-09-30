# Contributing

Use focused issues and pull requests with synthetic examples. Read [SECURITY.md](SECURITY.md) before reporting sensitive problems and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before participating.

## Development

Python 3.14 is the documented CLI runtime; macOS 14+ and Swift 6.4 are required for the app. Build and verification instructions are in [docs/development.md](docs/development.md). Never use production mailboxes for automated tests or include real keys, subjects, addresses, tokens, or password files in fixtures.

Describe the problem, resulting behavior, tests performed, and remaining limitations. Keep changes focused. Changes to matching, scope selection, sending, deletion, credentials, or GUI confirmation need meaningful regression coverage with mocked services. Update the relevant setup, privacy, operations, and limitations documentation when behavior changes.

Submitting code does not grant permission to operate a maintainer's mailbox or contact senders. Use your own authorised test account only when a live test is explicitly planned. Maintainers may request revisions or decline contributions. Do not add a separate CLA or claim third-party code belongs to this project; disclose provenance and licences in [NOTICE](NOTICE).

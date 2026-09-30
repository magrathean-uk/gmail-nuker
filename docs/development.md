# Development and verification

## Local checks

From the repository root:

```bash
python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("bin/gmail-block").read_text())'
./gmail-block --help
./gmail-block block --help
./gmail-block scan --help
./gmail-block unblock --help
./gmail-block delete --help
bash -n gmail-block run.sh
bash tests/check_app_service.sh
uv run --with-requirements app/runtime-requirements.txt python -m unittest discover -s tests -p 'test_*.py' -v
cd app
swift build -c release
```

Help and syntax/build checks do not authenticate or touch a mailbox. CLI operation tests must mock Google, network lookups, unsubscribe endpoints, and IMAP unless a live test against an explicitly authorised disposable mailbox is planned. Never send complaints or contact sender endpoints as part of CI.

## App packaging checks

Run `python3 scripts/package-app.py` for a generic local build, or pass a private nonsecret `--config` for a personal build. Verify `codesign --verify --deep --strict "dist/Gmail Nuker.app"`, launch the app from outside the checkout, and test its input/preview/cancel/confirmed-delete flow with a synthetic helper in a separate test bundle. Never replace the installed production helper with a fixture. Test the packaged 1Password bridge with mocked credentials/providers; a live profile check requires explicit operator authority.

Inspect the app and archive for private keys, cached tokens, credential files, and unintended mailbox metadata. A personal account configuration can contain a mailbox and vault-item reference, which should not enter a public build. Licences and pinned runtime versions are bundled in Resources/Licenses. Signing is ad hoc for local use, not Developer ID notarisation.

## Publication checks

Inspect git status, staged file names, and the staged diff. Keep secrets/, creds/, .env files, private-key files, credential JSON, databases, build directories, and compiled app bundles excluded. Scan for real keys, tokens, personal installation paths, mailbox metadata, and installation-specific identifiers. Ignore rules do not remove historical leaks.

Verify internal documentation links and actual flags. Include source changes in the changelog. Do not present a successful build as live authentication, filter matching, purge, or recovery verification.

## Release readiness

Before distributing an app, validate account configuration and subprocess discovery, test bounded and partial-failure cases with synthetic data, review automatic unsubscribe behavior, and complete signing/notarisation if the distribution route requires it. Document the exact tested platform and commit. Do not fabricate release numbers or attach local credential-bearing binaries.

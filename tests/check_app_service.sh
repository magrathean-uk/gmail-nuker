#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/gmail-nuker-service-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -swift-version 6 \
  "$repo_dir/app/Sources/GmailBlockApp/Models.swift" \
  "$repo_dir/app/Sources/GmailBlockApp/AccountConfiguration.swift" \
  "$repo_dir/app/Sources/GmailBlockApp/KeychainStore.swift" \
  "$repo_dir/app/Sources/GmailBlockApp/BlockService.swift" \
  "$repo_dir/tests/ServiceChecks.swift" \
  -o "$test_dir/service-checks"
"$test_dir/service-checks" "$repo_dir/tests/fixture_mail_engine.py"
# Quiet mode (used by the app): failures go to stderr with exit 1 and no osascript notification.
quiet_err="$(GMAIL_NUKER_NO_NOTIFY=1 PATH=/nonexistent /bin/bash "$repo_dir/scripts/mail-integration/block-sender.sh" "not a sender" 2>&1 >/dev/null)" && exit 1
[ "$quiet_err" = "Could not read a single sender address." ] || { echo "FAIL quiet block-sender failure: $quiet_err"; exit 1; }
echo "PASS quiet block-sender reports failure on stderr"

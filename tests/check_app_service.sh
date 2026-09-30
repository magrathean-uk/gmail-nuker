#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/gmail-nuker-service-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -swift-version 6 \
  "$repo_dir/app/Sources/GmailBlockApp/Models.swift" \
  "$repo_dir/app/Sources/GmailBlockApp/AccountConfiguration.swift" \
  "$repo_dir/app/Sources/GmailBlockApp/BlockService.swift" \
  "$repo_dir/tests/ServiceChecks.swift" \
  -o "$test_dir/service-checks"
"$test_dir/service-checks" "$repo_dir/tests/fixture_mail_engine.py"

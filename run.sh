#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="${SCRIPT_DIR}/GmailBlock.app"

if [ -d "${APP_BUNDLE}" ]; then
    open "${APP_BUNDLE}"
else
    "${SCRIPT_DIR}/app/.build/release/GmailBlockApp"
fi

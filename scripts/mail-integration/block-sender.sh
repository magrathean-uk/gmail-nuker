#!/bin/bash
# Block one sender with the installed Gmail Nuker engine. Usage: block-sender.sh "Name <addr@host>" | addr@host
# Exact sender only; filter to Trash + trash existing mail (recoverable; nothing is permanently deleted).
# Settings come from the app's saved defaults. The Google key comes from the macOS Keychain or 1Password.
set -uo pipefail
APP="/Applications/Gmail Nuker.app"
ENGINE="$APP/Contents/Resources/Engine/gmail-nuker-engine"
DOM="uk.magrathean.gmail-nuker"

notify() { /usr/bin/osascript -e 'on run a' -e 'display notification (item 2 of a) with title (item 1 of a)' -e 'end run' "$1" "$2" >/dev/null 2>&1; }

raw="${1:-}"
addr="$(printf '%s' "$raw" | /usr/bin/grep -Eo '[A-Za-z0-9._%+'"'"'-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' | head -1 | tr 'A-Z' 'a-z')"
[ -n "$addr" ] || { notify "Block sender" "No sender address found."; exit 1; }

mailbox="$(defaults read "$DOM" mailbox 2>/dev/null)"
ref="$(defaults read "$DOM" secretReference 2>/dev/null)"
source="$(defaults read "$DOM" credentialSource 2>/dev/null)"
if [ "$source" != "keychain" ] && [ "$source" != "1password" ]; then
  # No saved choice: prefer a Keychain key (metadata lookup only, no -w so no secret is read), then 1Password.
  if /usr/bin/security find-generic-password -s "$DOM" -a service-account >/dev/null 2>&1; then
    source="keychain"
  elif [ "${ref#op://}" != "$ref" ]; then
    source="1password"
  else
    source="keychain"
  fi
fi
configured=0
if [ -n "$mailbox" ]; then
  if [ "$source" = "keychain" ]; then
    /usr/bin/security find-generic-password -s "$DOM" -a service-account >/dev/null 2>&1 && configured=1
  else
    [ "${ref#op://}" != "$ref" ] && configured=1
  fi
fi
[ "$configured" = 1 ] || { notify "Block sender" "Gmail Nuker is not configured. Open the app Settings."; exit 1; }
[ "$addr" != "$(printf '%s' "$mailbox" | tr 'A-Z' 'a-z')" ] || { notify "Block sender" "Refusing to block your own address."; exit 1; }
[ -x "$ENGINE" ] || { notify "Block sender" "Gmail Nuker engine not found."; exit 1; }

out="$(GMAIL_NUKER_MAILBOX="$mailbox" GMAIL_NUKER_SECRET_REFERENCE="$ref" GMAIL_NUKER_SERVICE_ACCOUNT="" \
  GMAIL_NUKER_CREDENTIAL_SOURCE="$source" \
  "$ENGINE" block "$addr" --exact --commit --purge --json 2>&1)"
if printf '%s' "$out" | /usr/bin/grep -q '"success": *true'; then
  notify "Blocked" "$addr"
  echo "blocked $addr"
else
  msg="$(printf '%s' "$out" | /usr/bin/sed -n 's/.*"error": *"\([^"]*\)".*/\1/p' | head -1)"
  notify "Block failed" "${msg:-See engine output.}"
  echo "failed $addr: ${msg:-$out}" >&2
  exit 1
fi

#!/bin/bash
# Block one sender with the installed Gmail Nuker engine. Usage: block-sender.sh "Name <addr@host>" | addr@host
# Exact sender only; filter to Trash + trash existing mail (recoverable; nothing is permanently deleted).
# Settings come from the app's saved defaults. The Google key comes from the macOS Keychain or 1Password.
set -uo pipefail
APP="/Applications/Gmail Nuker.app"
ENGINE="$APP/Contents/Resources/Engine/gmail-nuker-engine"
DOM="uk.magrathean.gmail-nuker"

# GMAIL_NUKER_NO_NOTIFY=1: the caller (the app) shows the result itself from stdout/stderr and the exit code.
notify() {
  [ "${GMAIL_NUKER_NO_NOTIFY:-}" = 1 ] && return 0
  /usr/bin/osascript -e 'on run a' -e 'display notification (item 2 of a) with title (item 1 of a)' -e 'end run' "$1" "$2" >/dev/null 2>&1
}
fail() { echo "$1" >&2; notify "Block sender" "$1"; exit 1; }

raw="${1:-}"
trim() { local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }
addr_re="^[A-Za-z0-9._%+'-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\$"
# Only the address inside the LAST <...> counts; without brackets the whole input must be one address.
if [[ "$raw" == *"<"*">"* ]]; then
  candidate="${raw##*<}"; candidate="$(trim "${candidate%%>*}")"
else
  candidate="$(trim "$raw")"
fi
[[ "$candidate" =~ $addr_re ]] || fail "Could not read a single sender address."
addr="$(printf '%s' "$candidate" | tr 'A-Z' 'a-z')"

# Saved app settings first, then the bundled configuration of a preconfigured build.
cfg() {
  local v; v="$(defaults read "$DOM" "$1" 2>/dev/null)"
  [ -n "$v" ] || v="$(/usr/bin/plutil -extract "$1" raw -o - "$APP/Contents/Resources/AccountConfiguration.json" 2>/dev/null)"
  printf '%s' "$v"
}
mailbox="$(cfg mailbox)"
ref="$(cfg secretReference)"
sa_email="$(cfg serviceAccount)"
op_dir="$(cfg opConfigDirectory)"
source="$(cfg credentialSource)"

# Login keychain path, so only it is consulted (empty if it cannot be determined).
kc="$(/usr/bin/security login-keychain 2>/dev/null | tr -d ' \t"')"
kcargs=(); case "$kc" in /*) kcargs=("$kc");; esac
if [ "$source" != "keychain" ] && [ "$source" != "1password" ]; then
  # No saved choice: a legacy op:// reference means 1Password, otherwise the Keychain.
  if [ "${ref#op://}" != "$ref" ]; then source="1password"; else source="keychain"; fi
fi
configured=0
if [ -n "$mailbox" ]; then
  if [ "$source" = "keychain" ]; then
    /usr/bin/security find-generic-password -s "$DOM" -a service-account ${kcargs[@]+"${kcargs[@]}"} >/dev/null 2>&1 && configured=1
  else
    [ "${ref#op://}" != "$ref" ] && configured=1
  fi
fi
[ "$configured" = 1 ] || fail "Gmail Nuker is not configured. Open the app Settings."
[ "$addr" != "$(printf '%s' "$mailbox" | tr 'A-Z' 'a-z')" ] || fail "Refusing to block your own address."
[ -x "$ENGINE" ] || fail "Gmail Nuker engine not found."

extra=()
[ -z "$op_dir" ] || extra=("OP_CONFIG_DIR=${op_dir/#\~/$HOME}")
out="$(env GMAIL_NUKER_MAILBOX="$mailbox" GMAIL_NUKER_SECRET_REFERENCE="$ref" GMAIL_NUKER_SERVICE_ACCOUNT="$sa_email" \
  GMAIL_NUKER_CREDENTIAL_SOURCE="$source" ${extra[@]+"${extra[@]}"} \
  "$ENGINE" block "$addr" --exact --commit --purge --json 2>&1)"
if printf '%s' "$out" | /usr/bin/grep -q '"success": *true'; then
  moved="$(printf '%s' "$out" | /usr/bin/sed -n 's/.*"purged": *\([0-9]*\).*/\1/p' | tail -1)"
  notify "Blocked" "$addr"
  echo "blocked $addr ${moved:-0}"
else
  msg="$(printf '%s' "$out" | /usr/bin/sed -n 's/.*"error": *"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$msg" ] || msg="$(printf '%s\n' "$out" | /usr/bin/grep -v '^[[:space:]]*$' | tail -1)"
  notify "Block failed" "${msg:-See engine output.}"
  echo "${msg:-The block did not finish. Check Settings and try again.}" >&2
  exit 1
fi

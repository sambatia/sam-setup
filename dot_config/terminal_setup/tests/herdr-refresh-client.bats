#!/usr/bin/env bats

load lib/source-root

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
  local source_root
  local original_home="$HOME"
  source_root="$(cd "${TS_SOURCE_ROOT}" && pwd)"

  if [[ -d "${source_root}/dot_local" ]]; then
    RESOLVER="${source_root}/dot_local/private_libexec/private_executable_herdr-refresh-client"
  else
    RESOLVER="${original_home}/.local/libexec/herdr-refresh-client"
  fi

  TEST_TMPDIR_REAL="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  ORIGINAL_HOME_REAL="$(cd "$original_home" && pwd -P)"
  TEST_ROOT="$(mktemp -d "${TEST_TMPDIR_REAL}/herdr-refresh-client.XXXXXX")"
  TRUSTED_CACHE_ROOT="$(mktemp -d "${ORIGINAL_HOME_REAL}/.herdr-refresh-client-test.XXXXXX")"
  TEST_HOME="${TEST_ROOT}/home"
  FAKE_BIN="${TEST_ROOT}/bin"
  CALL_LOG="${TEST_ROOT}/calls.log"
  XDG_CACHE_HOME="${TRUSTED_CACHE_ROOT}/cache"
  mkdir -p "$TEST_HOME" "$FAKE_BIN" "$XDG_CACHE_HOME"
  chmod 700 "$TRUSTED_CACHE_ROOT" "$XDG_CACHE_HOME"
  : >"$CALL_LOG"

  export HOME="$TEST_HOME"
  export XDG_CACHE_HOME CALL_LOG
  export PATH="${FAKE_BIN}:/opt/homebrew/bin:/usr/bin:/bin"
  make_current_herdr
}

teardown() {
  case "${TEST_ROOT:-}" in
    "${TEST_TMPDIR_REAL}/herdr-refresh-client."*) /bin/rm -rf -- "$TEST_ROOT" ;;
  esac
  case "${TRUSTED_CACHE_ROOT:-}" in
    "${ORIGINAL_HOME_REAL}/.herdr-refresh-client-test."*) /bin/rm -rf -- "$TRUSTED_CACHE_ROOT" ;;
  esac
}

make_current_herdr() {
  printf '%s\n' \
    '#!/bin/bash' \
    'line="herdr"' \
    'for arg in "$@"; do line+=$'\''\t'\''"$arg"; done' \
    'printf "%s\n" "$line" >>"$CALL_LOG"' \
    'if [[ "${1:-}" == --session ]]; then shift 2; fi' \
    'case "$*" in' \
    '  "status server --json")' \
    '    if [[ -n "${HERDR_SERVER_OUTPUT+x}" ]]; then printf "%s" "$HERDR_SERVER_OUTPUT"; exit 0; fi' \
    '    compatible=true; restart=false' \
    '    [[ "${HERDR_COMPATIBLE:-yes}" == yes ]] || { compatible=false; restart=true; }' \
    '    printf "{\"status\":\"%s\",\"version\":\"%s\",\"protocol\":%s,\"compatible\":%s,\"restart_needed\":%s}\n" "${HERDR_SERVER_STATUS:-running}" "${HERDR_SERVER_VERSION:-0.8.2}" "${HERDR_SERVER_PROTOCOL:-20}" "$compatible" "$restart"' \
    '    ;;' \
    '  "status client --json")' \
    '    printf "{\"version\":\"%s\",\"protocol\":%s}\n" "${HERDR_CLIENT_VERSION:-0.8.2}" "${HERDR_CLIENT_PROTOCOL:-20}"' \
    '    ;;' \
    '  *) exit 9 ;;' \
    'esac' >"${FAKE_BIN}/herdr"
  chmod +x "${FAKE_BIN}/herdr"
}

make_cached_client() {
  local version="$1"
  local protocol="$2"
  local destination="${XDG_CACHE_HOME}/herdr-refresh/clients/${version}-p${protocol}/herdr"

  mkdir -p "${destination%/*}"
  chmod 700 \
    "$XDG_CACHE_HOME" \
    "${XDG_CACHE_HOME}/herdr-refresh" \
    "${XDG_CACHE_HOME}/herdr-refresh/clients" \
    "${destination%/*}"
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "cached-client\t%s\n" "$*" >>"$CALL_LOG"' \
    '[[ "$*" == "status client --json" ]] || exit 9' \
    "printf '{\"version\":\"%s\",\"protocol\":%s}\\n' '$version' '$protocol'" \
    >"$destination"
  chmod 700 "$destination"
  printf '%s\n' "$destination"
}

platform_asset_name() {
  case "$(uname -s):$(uname -m)" in
    Darwin:arm64 | Darwin:aarch64) printf '%s\n' herdr-macos-aarch64 ;;
    Darwin:x86_64 | Darwin:amd64) printf '%s\n' herdr-macos-x86_64 ;;
    Linux:aarch64 | Linux:arm64) printf '%s\n' herdr-linux-aarch64 ;;
    Linux:x86_64 | Linux:amd64) printf '%s\n' herdr-linux-x86_64 ;;
    *) return 1 ;;
  esac
}

prepare_download_fixture() {
  local version="$1"
  local protocol="$2"
  local digest_override="${3:-}"
  local asset_name
  local asset_url
  local digest
  local size

  RELEASE_ASSET="${TEST_ROOT}/release-asset"
  RELEASE_METADATA="${TEST_ROOT}/release.json"
  asset_name="$(platform_asset_name)"
  asset_url="https://github.com/herdrdev/herdr/releases/download/v${version}/${asset_name}"
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "downloaded-client\t%s\n" "$*" >>"$CALL_LOG"' \
    '[[ "$*" == "status client --json" ]] || exit 9' \
    "printf '{\"version\":\"%s\",\"protocol\":%s}\\n' '$version' '$protocol'" \
    >"$RELEASE_ASSET"
  chmod 755 "$RELEASE_ASSET"
  digest="$(shasum -a 256 "$RELEASE_ASSET" | awk '{print $1}')"
  [[ -z "$digest_override" ]] || digest="$digest_override"
  size="$(wc -c <"$RELEASE_ASSET" | tr -d ' ')"
  jq -n \
    --arg tag "v${version}" \
    --arg name "$asset_name" \
    --arg url "$asset_url" \
    --arg digest "sha256:${digest}" \
    --argjson size "$size" \
    '{tag_name:$tag,draft:false,assets:[{name:$name,state:"uploaded",browser_download_url:$url,digest:$digest,size:$size}]}' \
    >"$RELEASE_METADATA"
  export RELEASE_ASSET RELEASE_METADATA

  printf '%s\n' \
    '#!/bin/bash' \
    'output=""' \
    'while (($# > 0)); do' \
    '  case "$1" in' \
    '    -o) output="$2"; shift 2 ;;' \
    '    *) url="$1"; shift ;;' \
    '  esac' \
    'done' \
    'printf "curl\t%s\n" "$url" >>"$CALL_LOG"' \
    'case "$url" in' \
    '  https://api.github.com/*) cp "$RELEASE_METADATA" "$output" ;;' \
    '  https://github.com/*) cp "$RELEASE_ASSET" "$output" ;;' \
    '  *) exit 22 ;;' \
    'esac' >"${FAKE_BIN}/curl"
  chmod +x "${FAKE_BIN}/curl"
}

file_mode() {
  local value
  if value="$(stat -f '%Lp' "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    stat -c '%a' "$1"
  fi
}

@test "compatibility resolver is managed and executable" {
  [ -x "$RESOLVER" ]
}

@test "read-only mode returns the current compatible client without cache mutation" {
  run "$RESOLVER" --read-only

  [ "$status" -eq 0 ]
  [ "$output" = "${FAKE_BIN}/herdr" ]
  [ ! -e "${XDG_CACHE_HOME}/herdr-refresh" ]
  [ "$(sed -n '1p' "$CALL_LOG")" = $'herdr\tstatus\tserver\t--json' ]
}

@test "a stopped server safely selects the current client" {
  run env HERDR_SERVER_OUTPUT='{"status":"stopped"}' HOME="$HOME" \
    XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only

  [ "$status" -eq 0 ]
  [ "$output" = "${FAKE_BIN}/herdr" ]
  [ ! -e "${XDG_CACHE_HOME}/herdr-refresh" ]
}

@test "malformed or unknown server status fails closed" {
  local malformed_status

  for malformed_status in \
    '' \
    'not json at all' \
    '["running"]' \
    '{"status":"unknown"}' \
    '{"status":"running","version":"0.8.2","protocol":20}'; do
    : >"$CALL_LOG"
    run env HERDR_SERVER_OUTPUT="$malformed_status" HOME="$HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
      "$RESOLVER" --read-only

    [ "$status" -eq 2 ]
    [[ "$output" == *"server"*"invalid"* ]]
    [ ! -e "${XDG_CACHE_HOME}/herdr-refresh" ]
  done
}

@test "missing compatibility evidence cannot create cache or contact the network" {
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "curl\t%s\n" "$*" >>"$CALL_LOG"' \
    'exit 99' >"${FAKE_BIN}/curl"
  chmod +x "${FAKE_BIN}/curl"

  run env HERDR_SERVER_OUTPUT='{"status":"running","version":"0.7.5","protocol":17}' \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --ensure-cache

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid compatibility"* ]]
  [ ! -e "${XDG_CACHE_HOME}/herdr-refresh" ]
  run grep -q '^curl' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "contradictory or injected JSON evidence fails closed" {
  run env HERDR_SERVER_OUTPUT='{"status":["running"],"version":"0.8.2","protocol":20,"compatible":true}' \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid status"* ]]

  run env HERDR_SERVER_OUTPUT='{"status":"running","version":"0.8.2","protocol":20,"compatible":"yes"}' \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid compatibility"* ]]

  run env HERDR_SERVER_OUTPUT='{"status":"running","version":"0.8.2\ncompatible: yes","protocol":20,"compatible":false}' \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid version"* ]]

  run env HERDR_SERVER_OUTPUT='{"status":"running","version":"0.8.2","protocol":"twenty","compatible":true}' \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --ensure-cache
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid protocol"* ]]
  [ ! -e "${XDG_CACHE_HOME}/herdr-refresh" ]
}

# Regression: herdr 0.9.0 renamed the plain-text labels to private_protocol and
# private_protocol_compatible, which made label scraping fail closed on every
# healthy server. Resolution must depend on the JSON keys only.
@test "renamed plain-text status labels do not affect resolution" {
  printf '%s\n' \
    '#!/bin/bash' \
    'line="herdr"' \
    'for arg in "$@"; do line+=$'"'"'\t'"'"'"$arg"; done' \
    'printf "%s\n" "$line" >>"$CALL_LOG"' \
    'case "$*" in' \
    '  "status server")' \
    '    printf "status: running\nversion: 0.8.2\nprivate_protocol: 20\nprivate_protocol_compatible: yes\n"' \
    '    ;;' \
    '  "status server --json")' \
    '    printf "{\"status\":\"running\",\"version\":\"0.8.2\",\"protocol\":20,\"compatible\":true}\n"' \
    '    ;;' \
    '  "status client --json")' \
    '    printf "{\"version\":\"0.8.2\",\"protocol\":20}\n"' \
    '    ;;' \
    '  *) exit 9 ;;' \
    'esac' >"${FAKE_BIN}/herdr"
  chmod +x "${FAKE_BIN}/herdr"

  run "$RESOLVER" --read-only

  [ "$status" -eq 0 ]
  [ "$output" = "${FAKE_BIN}/herdr" ]
}

# Regression: `.compatible // ""` in jq swallows a literal false, which would
# read an incompatible server as "no compatibility evidence".
@test "an explicitly false compatibility flag is read as incompatible" {
  run env HERDR_SERVER_OUTPUT='{"status":"running","version":"0.7.5","protocol":17,"compatible":false}' \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only

  [ "$status" -eq 2 ]
  [[ "$output" == *"no validated Herdr 0.7.5 compatibility client is cached"* ]]
}

@test "a not_running server safely selects the current client" {
  run env HERDR_SERVER_OUTPUT='{"status":"not_running","version":null,"protocol":null,"compatible":null}' \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only

  [ "$status" -eq 0 ]
  [ "$output" = "${FAKE_BIN}/herdr" ]
  [ ! -e "${XDG_CACHE_HOME}/herdr-refresh" ]
}

@test "ensure-cache snapshots a compatible client with private ownership" {
  local cached_client="${XDG_CACHE_HOME}/herdr-refresh/clients/0.8.2-p20/herdr"

  run "$RESOLVER" --ensure-cache

  [ "$status" -eq 0 ]
  [ "$output" = "${FAKE_BIN}/herdr" ]
  [ -f "$cached_client" ]
  [ ! -L "$cached_client" ]
  [ "$(file_mode "$cached_client")" = 700 ]
  [ "$(file_mode "${XDG_CACHE_HOME}/herdr-refresh/clients/0.8.2-p20")" = 700 ]
}

@test "read-only mode selects a validated cached client for an incompatible server" {
  local cached_client
  cached_client="$(make_cached_client 0.7.5 17)"

  run env HERDR_COMPATIBLE=no HERDR_SERVER_VERSION=0.7.5 HERDR_SERVER_PROTOCOL=17 \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only

  [ "$status" -eq 0 ]
  [[ "$output" == *"using cached Herdr 0.7.5 client"* ]]
  [[ "$output" == *"$cached_client"* ]]
  run grep -Fx $'cached-client\tstatus client --json' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -q '^curl' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "quiet resolution suppresses routine cache-selection output" {
  local cached_client
  cached_client="$(make_cached_client 0.7.5 17)"

  run env HERDR_COMPATIBLE=no HERDR_SERVER_VERSION=0.7.5 HERDR_SERVER_PROTOCOL=17 \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only --quiet

  [ "$status" -eq 0 ]
  [ "$output" = "$cached_client" ]
}

@test "read-only mode fails closed when no compatible client is cached" {
  run env HERDR_COMPATIBLE=no HERDR_SERVER_VERSION=0.7.5 HERDR_SERVER_PROTOCOL=17 \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only

  [ "$status" -eq 2 ]
  [[ "$output" == *"no validated Herdr 0.7.5 compatibility client is cached"* ]]
  [ ! -e "${XDG_CACHE_HOME}/herdr-refresh" ]
}

@test "session selection is forwarded only to server inspection" {
  run "$RESOLVER" --read-only --session work-session

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$CALL_LOG")" = $'herdr\t--session\twork-session\tstatus\tserver\t--json' ]
}

@test "invalid arguments fail before contacting Herdr" {
  run "$RESOLVER" --read-only --session '../unsafe'
  [ "$status" -eq 2 ]
  [ ! -s "$CALL_LOG" ]

  run "$RESOLVER" --read-only --ensure-cache
  [ "$status" -eq 2 ]
  [ ! -s "$CALL_LOG" ]
}

@test "an unsafe cache anchor is never followed" {
  local outside="${TEST_ROOT}/outside-cache"
  local cache_link="${TEST_ROOT}/cache-link"
  mkdir -p "$outside"
  ln -s "$outside" "$cache_link"

  run env HERDR_COMPATIBLE=no HERDR_SERVER_VERSION=0.7.5 HERDR_SERVER_PROTOCOL=17 \
    HOME="$HOME" XDG_CACHE_HOME="$cache_link" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --read-only

  [ "$status" -eq 2 ]
  [[ "$output" == *"no validated Herdr 0.7.5 compatibility client is cached"* ]]
  [ -z "$(find "$outside" -mindepth 1 -print -quit)" ]
}

@test "ensure-cache downloads and verifies an official compatibility asset" {
  local cached_client="${XDG_CACHE_HOME}/herdr-refresh/clients/0.7.5-p17/herdr"
  prepare_download_fixture 0.7.5 17

  run env HERDR_COMPATIBLE=no HERDR_SERVER_VERSION=0.7.5 HERDR_SERVER_PROTOCOL=17 \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    RELEASE_ASSET="$RELEASE_ASSET" RELEASE_METADATA="$RELEASE_METADATA" \
    "$RESOLVER" --ensure-cache

  [ "$status" -eq 0 ]
  [[ "$output" == *"downloaded and verified Herdr 0.7.5 compatibility client"* ]]
  [[ "$output" == *"$cached_client"* ]]
  [ -f "$cached_client" ]
  [ "$(file_mode "$cached_client")" = 700 ]
  run "$cached_client" status client --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"version":"0.7.5"'* ]]
  [[ "$output" == *'"protocol":17'* ]]
}

@test "ensure-cache rejects an asset whose digest does not match metadata" {
  local cached_client="${XDG_CACHE_HOME}/herdr-refresh/clients/0.7.5-p17/herdr"
  prepare_download_fixture 0.7.5 17 "$(printf '%064d' 0)"

  run env HERDR_COMPATIBLE=no HERDR_SERVER_VERSION=0.7.5 HERDR_SERVER_PROTOCOL=17 \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    RELEASE_ASSET="$RELEASE_ASSET" RELEASE_METADATA="$RELEASE_METADATA" \
    "$RESOLVER" --ensure-cache

  [ "$status" -eq 2 ]
  [[ "$output" == *"failed integrity verification"* ]]
  [ ! -e "$cached_client" ]
}

@test "ensure-cache snapshots a compatible client under its own version when server version differs" {
  local cached_client="${XDG_CACHE_HOME}/herdr-refresh/clients/0.9.5-p22/herdr"

  run env HERDR_COMPATIBLE=yes HERDR_CLIENT_VERSION=0.9.5 HERDR_CLIENT_PROTOCOL=22 \
    HERDR_SERVER_VERSION=0.9.3 HERDR_SERVER_PROTOCOL=22 \
    HOME="$HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$RESOLVER" --ensure-cache

  [ "$status" -eq 0 ]
  [[ "$output" != *"warning: could not cache"* ]]
  [ -f "$cached_client" ]
  [ "$(file_mode "$cached_client")" = 700 ]
}

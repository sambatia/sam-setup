#!/usr/bin/env bats

load lib/source-root

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/prompt-latency.XXXXXX")"
  PROBE="${TS_SOURCE_ROOT}/dot_zshrc.d/prompt-latency-probe.zsh"
  ZSHRC="${TS_SOURCE_ROOT}/dot_zshrc"
}

teardown() {
  case "${TEST_ROOT:-}" in
    "${BATS_TEST_TMPDIR}/prompt-latency."*) /bin/rm -rf -- "$TEST_ROOT" ;;
  esac
}

file_mode() {
  local value
  if value="$(stat -f '%Lp' "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    stat -c '%a' "$1"
  fi
}

@test "latency diagnostics omit command text and use a private file" {
  local state_home="${TEST_ROOT}/state"
  local log="${state_home}/prompt_latency.log"
  local legacy_log="${state_home}/last_cmd.log"
  mkdir -p "$state_home"
  printf '%s\n' 'fixture command text' >"$legacy_log"
  chmod 644 "$legacy_log"

  run env XDG_STATE_HOME="$state_home" /bin/zsh -fc \
    'source "$1"; _plp_cmd_end=$((EPOCHREALTIME - 1)); _plp_line_init' \
    zsh "$PROBE"

  [ "$status" -eq 0 ]
  [ ! -e "$legacy_log" ]
  [ -f "$log" ]
  [ "$(file_mode "$log")" = 600 ]
  run grep -E 'cmd=|_plp_last_cmd|add-zsh-hook[[:space:]]+preexec' "$PROBE"
  [ "$status" -ne 0 ]
  run grep -F 'cmd=' "$log"
  [ "$status" -ne 0 ]
  run grep -F 'last_cmd.log' "$ZSHRC"
  [ "$status" -ne 0 ]
}

#!/usr/bin/env bats

load lib/source-root

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
  local source_root
  local original_home="$HOME"
  local default_doctor
  source_root="$(cd "${TS_SOURCE_ROOT}" && pwd)"

  default_doctor="${source_root}/dot_local/private_bin/executable_refresh-doctor"
  if [[ ! -x "$default_doctor" ]]; then
    default_doctor="${original_home}/.local/bin/refresh-doctor"
  fi
  DOCTOR="${REFRESH_DOCTOR_BIN:-$default_doctor}"
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/refresh-doctor.XXXXXX")"
  TEST_HOME="${TEST_ROOT}/home"
  TEST_BIN="${TEST_ROOT}/bin"
  CALL_LOG="${TEST_ROOT}/calls.log"
  mkdir -p "$TEST_HOME" "$TEST_BIN"
  : >"$CALL_LOG"

  export HOME="$TEST_HOME"
  export XDG_STATE_HOME="${TEST_ROOT}/state"
  export CALL_LOG
  export PATH="${TEST_BIN}:${PATH}"

  make_fake_herdr
}

teardown() {
  case "${TEST_ROOT:-}" in
    "${BATS_TEST_TMPDIR}/refresh-doctor."*) /bin/rm -rf -- "$TEST_ROOT" ;;
  esac
}

make_fake_herdr() {
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "%s\\n" "$*" >>"$CALL_LOG"' \
    'case "$*" in' \
    '  "--version")' \
    '    printf "%s\\n" "herdr 0.7.5"' \
    '    printf "%s\\n" "${HERDR_STDERR_SENTINEL:-}" >&2' \
    '    ;;' \
    '  "status --json")' \
    '    if [[ "${HERDR_STATUS_FAILURE:-0}" == 1 ]]; then printf "%s\\n" "SECRET-STATUS-STDERR" >&2; exit 9; fi' \
    '    compatible=true; [[ "${HERDR_COMPATIBLE:-yes}" == yes ]] || compatible=false' \
    '    restart=false; [[ "${HERDR_RESTART_NEEDED:-no}" == no ]] || restart=true' \
    '    printf "{\"client\":{\"version\":\"0.7.5\",\"channel\":\"stable\",\"protocol\":17},\"server\":{\"status\":\"running\",\"version\":\"0.7.5\",\"protocol\":17,\"compatible\":%s,\"socket\":\"/private/SECRET-SOCKET/herdr.sock\"},\"update\":{\"restart_needed\":%s},\"unknown_private_field\":\"SECRET-STATUS\"}\\n" "$compatible" "$restart"' \
    '    ;;' \
    '  *)' \
    '    printf "%s\\n" "unexpected fake herdr call: $*" >&2' \
    '    exit 9' \
    '    ;;' \
    'esac' \
    >"${TEST_BIN}/herdr"
  chmod +x "${TEST_BIN}/herdr"
}

record_files() {
  find "${TEST_ROOT}/state/herdr-refresh" -maxdepth 1 -type f \
    -name 'failure-*.json' -print 2>/dev/null | sort
}

file_mode() {
  local value
  if value="$(stat -f '%Lp' "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    stat -c '%a' "$1"
  fi
}

make_fake_refresh_tools() {
  mkdir -p "${TEST_HOME}/.local/bin"
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "controller" >>"$CALL_LOG"' \
    'printf "\t%s" "$@" >>"$CALL_LOG"' \
    'printf "\\n" >>"$CALL_LOG"' \
    '[[ "$*" != "--dry-run --quiet" ]] || exit 2' \
    'printf "%s\\n" "SECRET-CONTROLLER-OUTPUT w1:p1 cwd=/private/project"' \
    'printf "%s\\n" "SECRET-CONTROLLER-STDERR" >&2' \
    'exit "${DOCTOR_CONTROLLER_STATUS:-0}"' \
    >"${TEST_HOME}/.local/bin/herdr-refresh-safe-shell-panes"
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "worker" >>"$CALL_LOG"' \
    'printf "\t%s" "$@" >>"$CALL_LOG"' \
    'printf "\\n" >>"$CALL_LOG"' \
    'printf "%s\\n" "SECRET-WORKER-OUTPUT cwd=/private/startup"' \
    'printf "%s\\n" "SECRET-WORKER-STDERR" >&2' \
    'exit "${DOCTOR_WORKER_STATUS:-0}"' \
    >"${TEST_HOME}/.local/bin/zsh-refresh-current"
  chmod +x \
    "${TEST_HOME}/.local/bin/herdr-refresh-safe-shell-panes" \
    "${TEST_HOME}/.local/bin/zsh-refresh-current"
}

@test "record writes one private schema-1 JSON document" {
  local record state_mode record_mode

  run "$DOCTOR" --record \
    --component controller \
    --reason acknowledgement-timeout \
    --exit-status 1 \
    --discovered 34 \
    --eligible 23 \
    --excluded 1 \
    --skipped 10 \
    --refreshed 22 \
    --failed 1

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(record_files | wc -l | tr -d ' ')" -eq 1 ]
  record="$(record_files)"
  state_mode="$(file_mode "${TEST_ROOT}/state/herdr-refresh")"
  record_mode="$(file_mode "$record")"
  [ "$state_mode" = 700 ]
  [ "$record_mode" = 600 ]
  run jq -e '
    . == {
      schema_version: 1,
      recorded_at: .recorded_at,
      component: "controller",
      reasons: ["acknowledgement-timeout"],
      exit_status: 1,
      herdr_client_version: "0.7.5",
      counts: {
        discovered: 34,
        eligible: 23,
        excluded: 1,
        skipped: 10,
        refreshed: 22,
        failed: 1
      }
    }
    and (.recorded_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
  ' "$record"
  [ "$status" -eq 0 ]
}

@test "record rejects invalid values before creating state" {
  local -a invalid_commands

  invalid_commands=(
    "--component unknown --reason acknowledgement-timeout --exit-status 1"
    "--component controller --reason 'SECRET reason' --exit-status 1"
    "--component controller --reason acknowledgement-timeout --exit-status 0"
    "--component controller --reason acknowledgement-timeout --exit-status 256"
    "--component controller --reason acknowledgement-timeout --exit-status 1 --failed -1"
    "--component controller --reason acknowledgement-timeout --exit-status 1 --failed nope"
    "--component controller --exit-status 1"
    "--reason acknowledgement-timeout --exit-status 1"
    "--component controller --reason acknowledgement-timeout --exit-status 1 --unknown value"
  )

  for command_line in "${invalid_commands[@]}"; do
    # The fixtures are fixed literals above; eval is limited to splitting them
    # into the intended CLI argument vectors.
    eval "run \"\$DOCTOR\" --record $command_line"
    [ "$status" -eq 2 ]
  done
  [ ! -e "${TEST_ROOT}/state" ]
}

@test "record ignores a relative XDG state home" {
  export XDG_STATE_HOME="relative-state"
  cd "$TEST_ROOT"

  run "$DOCTOR" --record \
    --component current-shell \
    --reason startup-preflight-failed \
    --exit-status 1

  [ "$status" -eq 0 ]
  [ ! -e "${TEST_ROOT}/relative-state" ]
  [ "$(find "${TEST_HOME}/.local/state/herdr-refresh" -maxdepth 1 -type f -name 'failure-*.json' | wc -l | tr -d ' ')" -eq 1 ]
}

@test "record never persists raw diagnostics or environment data" {
  local record

  export HERDR_STDERR_SENTINEL="SECRET-HERDR-STDERR"
  export PRIVATE_ENV_SENTINEL="SECRET-ENVIRONMENT"
  mkdir -p "${TEST_ROOT}/SECRET-CWD"
  cd "${TEST_ROOT}/SECRET-CWD"

  run "$DOCTOR" --record \
    --component controller \
    --reason dispatch-failed \
    --reason acknowledgement-timeout \
    --reason dispatch-failed \
    --exit-status 1

  [ "$status" -eq 0 ]
  record="$(record_files)"
  run grep -E 'SECRET|private|socket|cwd|environment|stderr|pane|command' "$record"
  [ "$status" -eq 1 ]
  run jq -e '.reasons == ["acknowledgement-timeout", "dispatch-failed"]' "$record"
  [ "$status" -eq 0 ]
}

@test "record keeps only the ten newest controlled files" {
  local index
  local timestamp
  local state_dir="${TEST_ROOT}/state/herdr-refresh"
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  for index in {1..10}; do
    printf -v timestamp '20260101T0000%02dZ' "$index"
    printf '{}\n' >"${state_dir}/failure-${timestamp}-1-${index}.json"
    chmod 600 "${state_dir}/failure-${timestamp}-1-${index}.json"
  done
  printf 'keep\n' >"${state_dir}/unrelated.txt"

  run "$DOCTOR" --record \
    --component controller \
    --reason acknowledgement-timeout \
    --exit-status 1

  [ "$status" -eq 0 ]
  [ "$(record_files | wc -l | tr -d ' ')" -eq 10 ]
  [ -f "${state_dir}/unrelated.txt" ]
  [ ! -e "${state_dir}/failure-20260101T000001Z-1-1.json" ]
}

@test "record refuses an unsafe journal directory" {
  mkdir -p "${TEST_ROOT}/state"
  ln -s "${TEST_ROOT}/elsewhere" "${TEST_ROOT}/state/herdr-refresh"

  run "$DOCTOR" --record \
    --component controller \
    --reason acknowledgement-timeout \
    --exit-status 1

  [ "$status" -eq 2 ]
  [ ! -e "${TEST_ROOT}/elsewhere" ]
}

@test "doctor reports every layer without mutating or exposing raw data" {
  make_fake_refresh_tools
  "$DOCTOR" --record \
    --component controller \
    --reason acknowledgement-timeout \
    --exit-status 1 \
    --failed 1
  : >"$CALL_LOG"

  run "$DOCTOR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"client_version: 0.7.5"* ]]
  [[ "$output" == *"herdr_status: ok"* ]]
  [[ "$output" == *"pane_preflight: ok"* ]]
  [[ "$output" == *"shell_preflight: ok"* ]]
  [[ "$output" == *"latest_failure:"* ]]
  [[ "$output" == *'"reasons":["acknowledgement-timeout"]'* ]]
  [[ "$output" == *"result: healthy"* ]]
  [[ "$output" != *"SECRET"* ]]
  [[ "$output" != *"socket"* ]]
  [[ "$output" != *"w1:p1"* ]]
  [[ "$output" != *"/private/"* ]]
  run grep -Fx $'controller\t--dry-run' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx $'worker\t--check' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -E 'pane[[:space:]]+(run|send)|server[[:space:]]+stop|update|clear|exec' "$CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "doctor with no journal is read-only" {
  make_fake_refresh_tools
  [ ! -e "${TEST_ROOT}/state" ]

  run "$DOCTOR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"latest_failure: none"* ]]
  [ ! -e "${TEST_ROOT}/state" ]
}

@test "doctor runs remaining checks after one check fails" {
  make_fake_refresh_tools

  run env DOCTOR_CONTROLLER_STATUS=9 DOCTOR_WORKER_STATUS=8 \
    HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$DOCTOR"

  [ "$status" -eq 1 ]
  [[ "$output" == *"pane_preflight: failed"* ]]
  [[ "$output" == *"shell_preflight: failed"* ]]
  [[ "$output" == *"result: unhealthy"* ]]
  run grep -Fx $'controller\t--dry-run' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx $'worker\t--check' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "doctor rejects an unsafe latest failure record" {
  local state_dir="${TEST_ROOT}/state/herdr-refresh"
  make_fake_refresh_tools
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  printf '{}\n' >"${state_dir}/failure-20260729T180000Z-1-test.json"
  chmod 644 "${state_dir}/failure-20260729T180000Z-1-test.json"

  run "$DOCTOR"

  [ "$status" -eq 1 ]
  [[ "$output" == *"latest_failure: invalid"* ]]
  [[ "$output" == *"result: unhealthy"* ]]
}

@test "doctor rejects a symlinked failure record" {
  local state_dir="${TEST_ROOT}/state/herdr-refresh"
  make_fake_refresh_tools
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  printf '{}\n' >"${TEST_ROOT}/outside.json"
  ln -s "${TEST_ROOT}/outside.json" \
    "${state_dir}/failure-20260729T180000Z-1-test.json"

  run "$DOCTOR"

  [ "$status" -eq 1 ]
  [[ "$output" == *"latest_failure: invalid"* ]]
  [[ "$output" == *"result: unhealthy"* ]]
}

@test "doctor fails safely when Herdr status is unavailable" {
  make_fake_refresh_tools

  run env HERDR_STATUS_FAILURE=1 HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$DOCTOR"

  [ "$status" -eq 1 ]
  [[ "$output" == *"herdr_status: failed"* ]]
  [[ "$output" == *"pane_preflight: ok"* ]]
  [[ "$output" == *"shell_preflight: ok"* ]]
}

@test "doctor is unhealthy when the server is incompatible or needs restart" {
  make_fake_refresh_tools

  run env HERDR_COMPATIBLE=no HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$DOCTOR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"herdr_status: failed"* ]]
  [[ "$output" == *"compatible: no"* ]]

  : >"$CALL_LOG"
  run env HERDR_RESTART_NEEDED=yes HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$DOCTOR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"herdr_status: failed"* ]]
  [[ "$output" == *"restart_needed: yes"* ]]
}

@test "doctor help is non-mutating" {
  make_fake_refresh_tools

  run "$DOCTOR" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: refresh-doctor"* ]]
  [ ! -s "$CALL_LOG" ]
  [ ! -e "${TEST_ROOT}/state" ]
}

# Regression: herdr 0.9.0 renamed the server labels to private_protocol and
# private_protocol_compatible, so a doctor that scrapes labels reports a
# healthy server as unhealthy forever.
@test "doctor is healthy when only the plain-text status labels were renamed" {
  make_fake_refresh_tools
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "%s\\n" "$*" >>"$CALL_LOG"' \
    'case "$*" in' \
    '  "--version") printf "%s\\n" "herdr 0.7.5" ;;' \
    '  "status")' \
    '    printf "%s\\n" "server:" "  private_protocol: 17" "  private_protocol_compatible: yes"' \
    '    ;;' \
    '  "status --json")' \
    '    printf "%s\\n" "{\"client\":{\"version\":\"0.7.5\",\"channel\":\"stable\",\"protocol\":17},\"server\":{\"status\":\"running\",\"version\":\"0.7.5\",\"protocol\":17,\"compatible\":true},\"update\":{\"restart_needed\":false}}"' \
    '    ;;' \
    '  *) exit 9 ;;' \
    'esac' \
    >"${TEST_BIN}/herdr"
  chmod +x "${TEST_BIN}/herdr"

  run env HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$DOCTOR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"herdr_status: ok"* ]]
  [[ "$output" == *"compatible: yes"* ]]
  [[ "$output" == *"restart_needed: no"* ]]
  [[ "$output" != *"private_protocol"* ]]
}

@test "doctor surfaces server_binary_stale when reported by Herdr status JSON" {
  make_fake_refresh_tools
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "%s\\n" "$*" >>"$CALL_LOG"' \
    'case "$*" in' \
    '  "--version") printf "%s\\n" "herdr 0.9.5" ;;' \
    '  "status --json")' \
    '    printf "%s\\n" "{\"client\":{\"version\":\"0.9.5\",\"channel\":\"stable\",\"protocol\":22},\"server\":{\"status\":\"running\",\"version\":\"0.9.3\",\"protocol\":22,\"compatible\":true},\"update\":{\"server_binary_stale\":true,\"restart_needed\":false}}"' \
    '    ;;' \
    '  *) exit 9 ;;' \
    'esac' \
    >"${TEST_BIN}/herdr"
  chmod +x "${TEST_BIN}/herdr"

  run env HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$DOCTOR"

  [ "$status" -eq 0 ]
  [[ "$output" == *"herdr_status: ok"* ]]
  [[ "$output" == *"server_binary_stale: yes"* ]]
  [[ "$output" == *"restart_needed: no"* ]]
}

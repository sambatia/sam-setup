#!/usr/bin/env bats

load lib/source-root

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
  local original_home="$HOME"
  local source_root="${TS_SOURCE_ROOT}"
  local default_controller="${source_root}/dot_local/private_bin/executable_herdr-refresh-safe-shell-panes"
  local default_worker="${source_root}/dot_local/private_bin/executable_zsh-refresh-current"
  local default_doctor="${source_root}/dot_local/private_bin/executable_refresh-doctor"
  local default_resolver="${source_root}/dot_local/private_libexec/private_executable_herdr-refresh-client"
  local default_module="${source_root}/dot_zshrc.d/herdr-refresh.zsh"
  local default_module_loader="${source_root}/dot_zshrc.d/dot_module-loader.zsh"

  if [[ ! -x "$default_controller" ]]; then
    default_controller="${original_home}/.local/bin/herdr-refresh-safe-shell-panes"
    default_worker="${original_home}/.local/bin/zsh-refresh-current"
    default_doctor="${original_home}/.local/bin/refresh-doctor"
    default_resolver="${original_home}/.local/libexec/herdr-refresh-client"
    default_module="${original_home}/.zshrc.d/herdr-refresh.zsh"
    default_module_loader="${original_home}/.zshrc.d/.module-loader.zsh"
  fi

  export TEST_ROOT
  TEST_TMPDIR_REAL="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  ORIGINAL_HOME_REAL="$(cd "$original_home" && pwd -P)"
  TEST_ROOT="$(mktemp -d "${TEST_TMPDIR_REAL}/herdr-refresh.XXXXXX")"
  TRUSTED_CACHE_ROOT="$(mktemp -d "${ORIGINAL_HOME_REAL}/.herdr-refresh-test.XXXXXX")"
  export TEST_HOME="${TEST_ROOT}/home"
  export FAKE_BIN="${TEST_ROOT}/bin"
  export CALL_LOG="${TEST_ROOT}/calls.log"
  export CONTROLLER="${CONTROLLER:-$default_controller}"
  export WORKER="${WORKER:-$default_worker}"
  export DOCTOR="${DOCTOR:-$default_doctor}"
  export RESOLVER="${RESOLVER:-$default_resolver}"
  export MODULE="${MODULE:-$default_module}"
  export MODULE_LOADER_SOURCE="${MODULE_LOADER_SOURCE:-$default_module_loader}"
  export XDG_CACHE_HOME="${TRUSTED_CACHE_ROOT}/cache"
  export XDG_STATE_HOME="${TEST_ROOT}/state"

  mkdir -p "$TEST_HOME/.local/bin" "$TEST_HOME/.local/libexec" "$TEST_HOME/.zshrc.d" "$FAKE_BIN" "$XDG_CACHE_HOME"
  chmod 700 "$TRUSTED_CACHE_ROOT" "$XDG_CACHE_HOME"
  install -m 755 "$WORKER" "$TEST_HOME/.local/bin/zsh-refresh-current"
  install -m 755 "$DOCTOR" "$TEST_HOME/.local/bin/refresh-doctor"
  install -m 700 "$RESOLVER" "$TEST_HOME/.local/libexec/herdr-refresh-client"
  export HOME="$TEST_HOME"
  : >"$CALL_LOG"
  make_fake_herdr
  export PATH="${FAKE_BIN}:/opt/homebrew/bin:/usr/bin:/bin"
}

teardown() {
  local fixture_pid
  for fixture_pid in ${FIXTURE_PIDS:-}; do
    kill -CONT "$fixture_pid" 2>/dev/null || true
    kill "$fixture_pid" 2>/dev/null || true
    wait "$fixture_pid" 2>/dev/null || true
  done
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    case "$TEST_ROOT" in
      "${TEST_TMPDIR_REAL}/herdr-refresh."*) /bin/rm -rf -- "$TEST_ROOT" ;;
    esac
  fi
  case "${TRUSTED_CACHE_ROOT:-}" in
    "${ORIGINAL_HOME_REAL}/.herdr-refresh-test."*) /bin/rm -rf -- "$TRUSTED_CACHE_ROOT" ;;
  esac
}

make_fake_herdr() {
  printf '%s\n' \
    '#!/bin/bash' \
    'set -u' \
    'file_mode() {' \
    '  local value' \
    '  if value="$(stat -f '\''%Lp'\'' "$1" 2>/dev/null)"; then printf "%s\\n" "$value"; else stat -c '\''%a'\'' "$1"; fi' \
    '}' \
    'publish_acknowledgement() {' \
    '  local pane_id="$1" remote_command="$2" command_only worker_command ack_file="" challenge="" mode arg digest target pane_run_calls' \
    '  if [[ "${DROP_LEADING_CHAR_PANE:-}" == "$pane_id" ]]; then' \
    '    remote_command="${remote_command#"${remote_command%%[![:space:]]*}"}"' \
    '    remote_command="${remote_command#?}"' \
    '  fi' \
    '  if [[ -n "${REMOTE_JOB_STATE:-}" ]]; then' \
    '    REMOTE_COMMAND="$remote_command" /bin/zsh -f -c '\''if [[ $REMOTE_JOB_STATE == clean ]]; then :; elif [[ $REMOTE_JOB_STATE == late ]]; then TRAPUSR1() { /bin/sleep 30 >/dev/null 2>&1 & fixture_job=$!; unfunction TRAPUSR1; }; export CALLER_PID=$$; else /bin/sleep 30 >/dev/null 2>&1 & fixture_job=$!; fi; [[ $REMOTE_JOB_STATE != stopped ]] || { kill -STOP $fixture_job; /bin/sleep 0.05; }; eval "$REMOTE_COMMAND"; refresh_result=$?; zmodload zsh/parameter; print -r -- "survived:$refresh_result:${#jobstates}" >>"$CALL_LOG"; kill -CONT $fixture_job; kill $fixture_job; wait $fixture_job 2>/dev/null; exit 0'\'' </dev/null' \
    '    return $?' \
    '  fi' \
    '  command_only="${remote_command%% && exec /bin/zsh -l}"' \
    '  worker_command="${command_only##*; }"' \
    '  worker_command="${worker_command##* && }"' \
    '  jobstates=""' \
    '  eval "set -- $worker_command"' \
    '  [[ "${1:-}" == /*/zsh-refresh-current ]] || return 0' \
    '  while (($# > 0)); do' \
    '    arg="$1"' \
    '    case "$arg" in' \
    '      --ack-file) ack_file="${2:-}"; shift 2 ;;' \
    '      --challenge) challenge="${2:-}"; shift 2 ;;' \
    '      *) shift ;;' \
    '    esac' \
    '  done' \
    '  [[ -n "$ack_file" && -n "$challenge" ]] || return 0' \
    '  mode="${ACK_MODE:-success}"' \
    '  pane_run_calls="$(awk -F $'\''\t'\'' -v pane="$pane_id" '\''$2 == "pane" && $3 == "run" && $4 == pane { count += 1 } END { print count + 0 }'\'' "$CALL_LOG")"' \
    '  if [[ "${ACK_FAILURE_PANE:-}" == "$pane_id" ]] && ((pane_run_calls <= ${ACK_FAILURE_ATTEMPTS:-999999})); then mode="${ACK_FAILURE_MODE:-timeout}"; fi' \
    '  [[ "$mode" != timeout ]] || return 0' \
    '  if [[ -n "${WAIT_GATE_DIR:-}" ]]; then' \
    '    : >"${WAIT_GATE_DIR}/${pane_id//:/_}"' \
    '    attempts=0' \
    '    while ((attempts < 100)); do' \
    '      peer_count="$(find "$WAIT_GATE_DIR" -maxdepth 1 -type f | wc -l | tr -d " ")"' \
    '      ((peer_count >= WAIT_FOR_PEERS)) && break' \
    '      sleep 0.02' \
    '      ((attempts += 1))' \
    '    done' \
    '  fi' \
    '  digest="$(printf "%s" "$challenge" | shasum -a 256 | awk '\''{print $1}'\'')"' \
    '  printf "ack\\t%s\\t%s\\t%s\\n" "$pane_id" "$ack_file" "$(file_mode "${ack_file%/*}")" >>"$CALL_LOG"' \
    '  case "$mode" in' \
    '    wrong-digest) printf "%064d\\n" 0 >"$ack_file"; chmod 600 "$ack_file" ;;' \
    '    wrong-mode) printf "%s\\n" "$digest" >"$ack_file"; chmod 644 "$ack_file" ;;' \
    '    symlink) target="${ack_file}.target"; printf "%s\\n" "$digest" >"$target"; chmod 600 "$target"; ln -s "$target" "$ack_file" ;;' \
    '    *) printf "%s\\n" "$digest" >"$ack_file"; chmod 600 "$ack_file" ;;' \
    '  esac' \
    '}' \
    'log_line="herdr"' \
    'for arg in "$@"; do log_line+=$'\''\t'\''"$arg"; done' \
    'printf "%s\\n" "$log_line" >>"$CALL_LOG"' \
    'if [[ "${1:-}" == --session ]]; then shift 2; fi' \
    'case "$*" in' \
    '  "status server --json")' \
    '    compatible=true; [[ "${HERDR_COMPATIBLE:-yes}" == yes ]] || compatible=false' \
    '    printf "{\"status\":\"running\",\"version\":\"%s\",\"protocol\":%s,\"compatible\":%s}\\n" "${HERDR_SERVER_VERSION:-0.8.2}" "${HERDR_SERVER_PROTOCOL:-20}" "$compatible"' \
    '    ;;' \
    '  "status client --json")' \
    '    printf "{\"version\":\"%s\",\"protocol\":%s}\\n" "${HERDR_CLIENT_VERSION:-0.8.2}" "${HERDR_CLIENT_PROTOCOL:-20}"' \
    '    ;;' \
    '  "pane list")' \
    '    if [[ "${FAIL_PANE_LIST:-0}" == 1 ]]; then echo "server unavailable" >&2; exit 9; fi' \
    '    if [[ "${SERVER_NOT_RUNNING:-0}" == 1 ]]; then printf "%s\\n" "{\"id\":\"cli:pane:list\",\"error\":{\"code\":\"server_not_running\",\"message\":\"no herdr server is running at /tmp/herdr.sock; run herdr to start or attach it\"}}" >&2; exit 1; fi' \
    '    if [[ "${INVALID_PANE_LIST:-0}" == 1 ]]; then printf "%s" "not-json"; exit 0; fi' \
    '    if [[ -n "${PANE_LIST_JSON+x}" ]]; then printf "%s" "$PANE_LIST_JSON"; else printf "%s" '\''{"result":{"panes":[{"pane_id":"w1:p1"},{"pane_id":"w1:p2"}]}}'\''; fi' \
    '    ;;' \
    '  "pane process-info --pane w1:p1")' \
    '    p1_calls="$(grep -c $'\''^herdr\tpane\tprocess-info\t--pane\tw1:p1$'\'' "$CALL_LOG")"' \
    '    if [[ "$p1_calls" -gt 2 && "${ACK_BEFORE_RETRY_PANE:-}" == "w1:p1" ]]; then first_run_command="$(awk -F $'\''\t'\'' '\''$2 == "pane" && $3 == "run" && $4 == "w1:p1" { print $5; exit }'\'' "$CALL_LOG")"; ACK_FAILURE_PANE="" ACK_MODE=success publish_acknowledgement w1:p1 "$first_run_command"; fi' \
    '    if [[ "${FAIL_PROCESS_PANE:-}" == "w1:p1" || ("${FAIL_PROCESS_PANE_SECOND:-}" == "w1:p1" && "$p1_calls" -gt 1) ]]; then echo "process unavailable" >&2; exit 9; fi' \
    '    if [[ "$p1_calls" -gt 2 && -n "${P1_PROCESS_JSON_THIRD+x}" ]]; then printf "%s" "$P1_PROCESS_JSON_THIRD"; elif [[ "$p1_calls" -gt 1 && -n "${P1_PROCESS_JSON_SECOND+x}" ]]; then printf "%s" "$P1_PROCESS_JSON_SECOND"; elif [[ -n "${P1_PROCESS_JSON+x}" ]]; then printf "%s" "$P1_PROCESS_JSON"; else printf "%s" '\''{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'\''; fi' \
    '    ;;' \
    '  "pane process-info --pane w1:p2")' \
    '    if [[ "${FAIL_PROCESS_PANE:-}" == "w1:p2" ]]; then echo "process unavailable" >&2; exit 9; fi' \
    '    if [[ -n "${P2_PROCESS_JSON+x}" ]]; then printf "%s" "$P2_PROCESS_JSON"; else printf "%s" '\''{"result":{"process_info":{"foreground_processes":[{"name":"node"}]}}}'\''; fi' \
    '    ;;' \
    '  "pane run"*)' \
    '    pane_run_calls="$(awk -F $'\''\t'\'' -v pane="$3" '\''$2 == "pane" && $3 == "run" && $4 == pane { count += 1 } END { print count + 0 }'\'' "$CALL_LOG")"' \
    '    if [[ "${FAIL_RUN_PANE:-}" == "$3" ]] && ((pane_run_calls <= ${FAIL_RUN_ATTEMPTS:-999999})); then echo "dispatch failed" >&2; exit 9; fi' \
    '    if [[ -n "${WAIT_GATE_DIR:-}" ]]; then publish_acknowledgement "$3" "$4" & else publish_acknowledgement "$3" "$4"; fi' \
    '    exit 0' \
    '    ;;' \
    '  "pane wait-output"*)' \
    '    if [[ "${FAIL_WAIT_PANE:-}" == "$3" ]]; then echo "wait failed" >&2; exit 9; fi' \
    '    exit 0' \
    '    ;;' \
    '  *) echo "unexpected fake herdr call: $*" >&2; exit 8 ;;' \
    'esac' >"${FAKE_BIN}/herdr"
  chmod +x "${FAKE_BIN}/herdr"
}

make_fake_refresh_commands() {
  # Reloaded definitions must see the same isolated replacement-shell stub.
  # Keep the real pending-job guard in place even in this test double.
  cp "$MODULE" "$TEST_HOME/.zshrc.d/herdr-refresh.zsh"
  cat >>"$TEST_HOME/.zshrc.d/herdr-refresh.zsh" <<'ZSH'
_herdr_refresh_exec_shell() {
  _herdr_refresh_require_no_jobs || return $?
  print -r -- exec-shell >>"$CALL_LOG"
}
ZSH
  printf '%s\n' \
    '#!/bin/bash' \
    'printf "controller" >>"$CALL_LOG"' \
    'for arg in "$@"; do printf "\t%s" "$arg" >>"$CALL_LOG"; done' \
    'printf "\n" >>"$CALL_LOG"' \
    '[[ "${JOBS_DURING:-}" != controller ]] || kill -USR1 "$CALLER_PID"' \
    '[[ "${FAIL_CONTROLLER:-0}" != 1 ]]' \
    >"${TEST_HOME}/.local/bin/herdr-refresh-safe-shell-panes"
  chmod +x "${TEST_HOME}/.local/bin/herdr-refresh-safe-shell-panes"

  printf '%s\n' \
    '#!/bin/bash' \
    'printf "worker" >>"$CALL_LOG"' \
    'for arg in "$@"; do printf "\t%s" "$arg" >>"$CALL_LOG"; done' \
    'printf "\n" >>"$CALL_LOG"' \
    '[[ "${JOBS_DURING:-}" != worker ]] || kill -USR1 "$CALLER_PID"' \
    '[[ "${FAIL_WORKER:-0}" != 1 ]]' \
    >"${TEST_HOME}/.local/bin/zsh-refresh-current"
  chmod +x "${TEST_HOME}/.local/bin/zsh-refresh-current"

  printf '%s\n' \
    '#!/bin/bash' \
    'printf "doctor" >>"$CALL_LOG"' \
    'for arg in "$@"; do printf "\t%s" "$arg" >>"$CALL_LOG"; done' \
    'printf "\n" >>"$CALL_LOG"' \
    '[[ "${FAIL_DIAGNOSTIC_WRITER:-0}" != 1 ]]' \
    >"${TEST_HOME}/.local/bin/refresh-doctor"
  chmod +x "${TEST_HOME}/.local/bin/refresh-doctor"

  printf '%s\n' \
    '#!/bin/bash' \
    'printf "clear\n" >>"$CALL_LOG"' \
    >"${FAKE_BIN}/clear"
  chmod +x "${FAKE_BIN}/clear"
}

make_isolated_zdotdir() {
  local zdotdir="$1"
  mkdir -p "$zdotdir"
  # Keep host-owned global startup files outside these user-startup fixtures.
  printf '%s\n' 'unsetopt GLOBAL_RCS' >"${zdotdir}/.zshenv"
}

file_mode() {
  local value
  if value="$(stat -f '%Lp' "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  else
    stat -c '%a' "$1"
  fi
}

diagnostic_records() {
  find "${XDG_STATE_HOME}/herdr-refresh" -maxdepth 1 -type f \
    -name 'failure-*.json' -print 2>/dev/null | sort
}

@test "controller help is non-mutating" {
  run "$CONTROLLER" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"default: 15000"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "worker help is non-mutating" {
  run "$WORKER" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "controller defaults to a dry run" {
  run "$CONTROLLER"

  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  run grep -q $'^herdr\tpane\trun' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "controller resolves a compatible client before pane discovery" {
  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$CALL_LOG")" = $'herdr\tstatus\tserver\t--json' ]
}

@test "controller forwards the selected session to compatibility resolution" {
  run "$CONTROLLER" --dry-run --session test-session

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$CALL_LOG")" = $'herdr\t--session\ttest-session\tstatus\tserver\t--json' ]
}

@test "pane-list command failure is an infrastructure error" {
  run env FAIL_PANE_LIST=1 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER"

  [ "$status" -eq 2 ]
  [[ "$output" == *"server unavailable"* ]]
}

make_fake_boot_time() {
  # sysctl lives in /usr/sbin, outside the test PATH; the fake keeps the boot
  # time deterministic on macOS and Linux alike.
  printf '%s\n' \
    '#!/bin/bash' \
    'if [[ "$*" == "-n kern.boottime" ]]; then printf "%s\\n" "{ sec = 1789630673, usec = 409888 } Thu Sep 17 01:37:53 2026"; exit 0; fi' \
    'exit 1' >"${FAKE_BIN}/sysctl"
  chmod +x "${FAKE_BIN}/sysctl"
}

make_unknown_boot_time() {
  printf '%s\n' '#!/bin/bash' 'exit 1' >"${FAKE_BIN}/sysctl"
  printf '%s\n' '#!/bin/bash' 'exit 1' >"${FAKE_BIN}/uptime"
  chmod +x "${FAKE_BIN}/sysctl" "${FAKE_BIN}/uptime"
}

@test "a stopped Herdr server is explained with the boot time and recorded" {
  make_fake_boot_time

  run env SERVER_NOT_RUNNING=1 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"pane discovery failed"* ]]
  [[ "$output" == *'"code":"server_not_running"'* ]]
  [[ "$output" == *"no Herdr server is running; refresh needs a live Herdr session (this Mac last booted Thu Sep 17 01:37:53 2026)"* ]]
  [[ "$output" == *"start 'herdr' first, then run refresh again from a Herdr pane"* ]]
  ! grep -q $'^herdr\tpane\trun' "$CALL_LOG"
  [ "$(diagnostic_records | wc -l | tr -d ' ')" -eq 1 ]
  record="$(diagnostic_records)"
  run jq -e '
    .component == "controller" and
    .reasons == ["herdr-server-not-running", "pane-discovery-failed"] and
    .exit_status == 2 and
    .counts.discovered == 0
  ' "$record"
  [ "$status" -eq 0 ]
}

@test "a stopped Herdr server is still explained when the boot time is unknown" {
  make_unknown_boot_time

  run env SERVER_NOT_RUNNING=1 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER"

  [ "$status" -eq 2 ]
  [[ "$output" == *"no Herdr server is running; refresh needs a live Herdr session"* ]]
  [[ "$output" != *"last booted"* ]]
  [[ "$output" == *"start 'herdr' first"* ]]
}

@test "other pane discovery failures keep the raw error without server guidance" {
  make_fake_boot_time

  run env FAIL_PANE_LIST=1 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"server unavailable"* ]]
  [[ "$output" != *"no Herdr server is running"* ]]
  [[ "$output" != *"last booted"* ]]
  record="$(diagnostic_records)"
  run jq -e '.reasons == ["pane-discovery-failed"]' "$record"
  [ "$status" -eq 0 ]
}

@test "invalid pane-list JSON is an infrastructure error" {
  run env INVALID_PANE_LIST=1 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER"

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid"*"JSON"* ]]
}

@test "apply excludes the invoking pane and preserves scrollback by default" {
  run "$CONTROLLER" --apply --exclude-pane w1:p1

  [ "$status" -eq 0 ]
  run grep -q $'^herdr\tpane\trun\tw1:p1' "$CALL_LOG"
  [ "$status" -ne 0 ]
  run grep -q -- '--clear' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "worker check accepts a valid isolated Zsh startup" {
  local zdotdir="${TEST_ROOT}/valid-zdot"
  make_isolated_zdotdir "$zdotdir"
  printf '%s\n' 'typeset -g REFRESH_FIXTURE=ready' >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "worker check accepts a complete Zsh module inventory" {
  local zdotdir="${TEST_ROOT}/complete-modules-zdot"
  make_isolated_zdotdir "$zdotdir"
  mkdir -p "${zdotdir}/.zshrc.d"
  cp "$MODULE_LOADER_SOURCE" "${zdotdir}/.zshrc.d/.module-loader.zsh"
  printf '%s\n' listed.zsh >"${zdotdir}/.zshrc.d/.module-order"
  : >"${zdotdir}/.zshrc.d/listed.zsh"
  : >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "worker check rejects an invalid optional plugin loader during syntax preflight" {
  local zdotdir="${TEST_ROOT}/invalid-plugin-loader-zdot"
  make_isolated_zdotdir "$zdotdir"
  mkdir -p "${zdotdir}/.zshrc.d"
  printf '%s\n' 'if then' >"${zdotdir}/.zshrc.d/.optional-plugin-loader.zsh"
  : >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"preflight failed (startup syntax)"* ]]
  [[ "$output" == *".optional-plugin-loader.zsh"* ]]
}

@test "worker check rejects an unlisted Zsh module" {
  local zdotdir="${TEST_ROOT}/unlisted-module-zdot"
  make_isolated_zdotdir "$zdotdir"
  mkdir -p "${zdotdir}/.zshrc.d"
  cp "$MODULE_LOADER_SOURCE" "${zdotdir}/.zshrc.d/.module-loader.zsh"
  printf '%s\n' listed.zsh >"${zdotdir}/.zshrc.d/.module-order"
  : >"${zdotdir}/.zshrc.d/listed.zsh"
  : >"${zdotdir}/.zshrc.d/orphan.zsh"
  : >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"unlisted module: orphan.zsh"* ]]
}

@test "worker rejects a silent runtime module failure before later modules load" {
  local zdotdir="${TEST_ROOT}/runtime-failure-zdot"
  local load_log="${TEST_ROOT}/runtime-load.log"
  make_isolated_zdotdir "$zdotdir"
  mkdir -p "${zdotdir}/.zshrc.d"
  cp "$MODULE_LOADER_SOURCE" "${zdotdir}/.zshrc.d/.module-loader.zsh"
  printf '%s\n' failing.zsh later.zsh >"${zdotdir}/.zshrc.d/.module-order"
  printf '%s\n' 'return 1' >"${zdotdir}/.zshrc.d/failing.zsh"
  printf 'print -r -- later >> %q\n' "$load_log" >"${zdotdir}/.zshrc.d/later.zsh"
  printf '%s\n' \
    'source "$ZDOTDIR/.zshrc.d/.module-loader.zsh"' \
    'terminal_load_zsh_modules "$ZDOTDIR/.zshrc.d" "$ZDOTDIR/.zshrc.d/.module-order"' \
    >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"module failed: failing.zsh"* ]]
  [ ! -e "$load_log" ]
}

@test "worker check rejects a startup syntax error" {
  local zdotdir="${TEST_ROOT}/invalid-zdot"
  make_isolated_zdotdir "$zdotdir"
  printf '%s\n' 'if then' >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"preflight failed"* ]]
}

@test "worker follows a ZDOTDIR change made by zshenv" {
  local zdotdir="${TEST_ROOT}/redirect-zdot"
  make_isolated_zdotdir "$zdotdir"
  mkdir -p "$zdotdir/next"
  printf '%s\n' 'export ZDOTDIR="$ZDOTDIR/next"' >>"${zdotdir}/.zshenv"
  printf '%s\n' 'print -u2 -- redirected-startup-ran' >"${zdotdir}/next/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"redirected-startup-ran"* ]]
}

@test "worker rejects an unsafe acknowledgement challenge" {
  run env HOME="$TEST_HOME" ZDOTDIR="${TEST_ROOT}/empty-zdot" TERM=xterm-256color "$WORKER" --check --challenge $'unsafe\e[31m'

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid challenge"* ]]
}

@test "worker publishes a private acknowledgement without terminal output" {
  local zdotdir="${TEST_ROOT}/ack-zdot"
  local ack_dir="${TEST_ROOT}/worker-acks"
  local ack_file="${ack_dir}/ack-p1"
  local challenge='refresh:file-ack-1'
  local expected_digest
  make_isolated_zdotdir "$zdotdir"
  mkdir -m 700 "$ack_dir"
  printf '%s\n' 'return 0' >"${zdotdir}/.zshrc"
  expected_digest="$(printf '%s' "$challenge" | shasum -a 256 | awk '{print $1}')"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color \
    "$WORKER" --check --ack-file "$ack_file" --challenge "$challenge"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "$ack_file" ]
  [ ! -L "$ack_file" ]
  [ "$(file_mode "$ack_file")" = 600 ]
  [ "$(wc -c <"$ack_file" | tr -d ' ')" -eq 65 ]
  [ "$(sed -n '1p' "$ack_file")" = "$expected_digest" ]
  [[ "$output" != *"herdr-refresh-ok-"* ]]
  [[ "$output" != *$'\033[8m'* ]]
}

@test "worker requires acknowledgement path and challenge together" {
  local ack_dir="${TEST_ROOT}/worker-acks"
  mkdir -m 700 "$ack_dir"

  run "$WORKER" --check --ack-file "${ack_dir}/ack-p1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--ack-file and --challenge must be combined"* ]]

  run "$WORKER" --check --challenge refresh:file-ack-1
  [ "$status" -eq 2 ]
  [[ "$output" == *"--ack-file and --challenge must be combined"* ]]
}

@test "worker rejects an unsafe acknowledgement path" {
  local public_dir="${TEST_ROOT}/public-acks"
  mkdir -m 755 "$public_dir"

  run "$WORKER" --check --ack-file relative/ack-p1 --challenge refresh:file-ack-1
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid acknowledgement path"* ]]

  run "$WORKER" --check --ack-file "${public_dir}/ack-p1" --challenge refresh:file-ack-1
  [ "$status" -eq 2 ]
  [[ "$output" == *"acknowledgement directory must be private"* ]]
}

@test "worker never clobbers a pre-existing acknowledgement" {
  local ack_dir="${TEST_ROOT}/worker-acks"
  local ack_file="${ack_dir}/ack-p1"
  mkdir -m 700 "$ack_dir"
  printf '%s\n' 'preserve-me' >"$ack_file"

  run "$WORKER" --check --ack-file "$ack_file" --challenge refresh:file-ack-1

  [ "$status" -eq 2 ]
  [[ "$output" == *"acknowledgement path already exists"* ]]
  [ "$(sed -n '1p' "$ack_file")" = preserve-me ]
}

@test "worker does not acknowledge a failed explicit clear" {
  local zdotdir="${TEST_ROOT}/clear-zdot"
  local ack_dir="${TEST_ROOT}/worker-acks"
  local ack_file="${ack_dir}/ack-p1"
  make_isolated_zdotdir "$zdotdir"
  mkdir -m 700 "$ack_dir"
  printf '%s\n' 'return 0' >"${zdotdir}/.zshrc"
  printf '%s\n' '#!/bin/bash' 'exit 1' >"${FAKE_BIN}/clear"
  chmod +x "${FAKE_BIN}/clear"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=xterm-256color PATH="$PATH" \
    "$WORKER" --clear --ack-file "$ack_file" --challenge refresh:clear-1

  [ "$status" -eq 1 ]
  [[ "$output" == *"clear failed"* ]]
  [ ! -e "$ack_file" ]
}

@test "worker rejects unknown arguments without replacing the shell" {
  run "$WORKER" --unknown

  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown argument"* ]]
}

@test "worker permanently removes temporary startup captures" {
  run grep -Eq '(^|[[:space:]])(/usr/bin/)?trash([[:space:]]|$)' "$WORKER"

  [ "$status" -ne 0 ]
}

@test "worker removes its capture directory after execution" {
  local zdotdir="${TEST_ROOT}/cleanup-zdot"
  local tmpdir="${TEST_ROOT}/worker-tmp"
  make_isolated_zdotdir "$zdotdir"
  mkdir -p "$tmpdir"
  printf '%s\n' 'return 0' >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TMPDIR="$tmpdir" TERM=xterm-256color "$WORKER" --check

  [ "$status" -eq 0 ]
  run find "$tmpdir" -maxdepth 1 -type d -name 'zsh-refresh-current.*' -print
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "worker timeout prevents delayed startup completion" {
  local zdotdir="${TEST_ROOT}/timeout-zdot"
  local late_file="${TEST_ROOT}/late-startup"
  local ack_dir="${TEST_ROOT}/worker-acks"
  local ack_file="${ack_dir}/ack-p1"
  make_isolated_zdotdir "$zdotdir"
  mkdir -m 700 "$ack_dir"
  printf '%s\n' 'sleep 1' 'print -r -- late >"$LATE_FILE"' >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" LATE_FILE="$late_file" TERM=xterm-256color \
    "$WORKER" --check --timeout-ms 100 --ack-file "$ack_file" --challenge refresh:timeout-1

  [ "$status" -eq 1 ]
  [[ "$output" == *"preflight timed out"* ]]
  [ ! -e "$ack_file" ]
  sleep 1.1
  [ ! -e "$late_file" ]
}

@test "controller deduplicates pane IDs and classifies idle Zsh only" {
  export PANE_LIST_JSON='{"result":{"panes":[{"pane_id":"w1:p1"},{"pane_id":"w1:p1"},{"pane_id":"w1:p2"}]}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"ELIGIBLE w1:p1"* ]]
  [[ "$output" == *"SKIP w1:p2"* ]]
  [[ "$output" == *"discovered=2"* ]]
  [[ "$output" == *"eligible=1"* ]]
  [[ "$output" == *"skipped=1"* ]]
}

@test "controller rejects an unsafe caller pane ID" {
  run "$CONTROLLER" --exclude-pane $'w1:p1;\e[31m'

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid pane ID"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "controller skips mixed foreground process groups" {
  export P1_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"},{"name":"bash"}]}}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1"* ]]
  [[ "$output" != *"ELIGIBLE w1:p1"* ]]
}

@test "controller rejects a foreground record with no process identity" {
  export P1_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"},{}]}}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1"* ]]
  [[ "$output" != *"ELIGIBLE w1:p1"* ]]
}

@test "controller does not split comma-containing process names" {
  export P1_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh,zsh"}]}}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1"* ]]
  [[ "$output" != *"ELIGIBLE w1:p1"* ]]
}

@test "controller does not expose process command lines or cwd" {
  export P1_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh","argv":["zsh","secret-argument"],"cmdline":"zsh secret-argument","cwd":"/private/project"}]}}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" != *"secret-argument"* ]]
  [[ "$output" != *"/private/project"* ]]
}

@test "controller reports successful no-op when every discovered pane is busy" {
  export P1_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"node"}]}}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"eligible=0"* ]]
  [[ "$output" == *"No eligible panes"* ]]
}

@test "controller treats unavailable process information as an infrastructure failure" {
  run env FAIL_PROCESS_PANE=w1:p1 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"SKIP w1:p1"*"process-info-unavailable"* ]]
}

@test "controller skips omitted optional foreground information while refreshing known idle peers" {
  export P1_PROCESS_JSON='{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","shell_pid":14075}}}'
  export P2_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'

  run "$CONTROLLER" --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=foreground-unknown"* ]]
  [[ "$output" == *"refreshed=1 failed=0"* ]]
  ! grep -Eq $'^herdr\tpane\trun\tw1:p1\t' "$CALL_LOG"
  grep -Eq $'^herdr\tpane\trun\tw1:p2\t' "$CALL_LOG"
  [ "$(diagnostic_records | wc -l | tr -d ' ')" -eq 0 ]
}

@test "controller accepts a schema-valid pane identity with no optional process fields as unknown" {
  export P1_PROCESS_JSON='{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1"}}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=foreground-unknown"* ]]
  [[ "$output" == *"eligible=0"* ]]
}

@test "controller never dispatches when optional foreground information disappears before dispatch" {
  export P1_PROCESS_JSON_SECOND='{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","shell_pid":14075}}}'

  run "$CONTROLLER" --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=changed-before-dispatch"* ]]
  ! grep -Eq $'^herdr\tpane\trun\t' "$CALL_LOG"
}

@test "controller still aborts on malformed or mismatched optional foreground responses" {
  local fixture
  for fixture in \
    '{"result":{"process_info":{}}}' \
    '{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p2"}}}' \
    '{"result":{"type":"other","process_info":{"pane_id":"w1:p1"}}}' \
    '{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","foreground_processes":null}}}' \
    '{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","foreground_processes":{}}}}'; do
    export P1_PROCESS_JSON="$fixture"
    run "$CONTROLLER" --apply
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid-process-info"* ]]
    ! grep -Eq $'^herdr\tpane\trun\t' "$CALL_LOG"
  done
}

@test "controller rejects valid JSON with an unexpected pane-list schema" {
  run env PANE_LIST_JSON='{}' PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid pane-list schema"* ]]
}

@test "inspection failure prevents every mutation" {
  run env FAIL_PROCESS_PANE=w1:p2 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 2 ]
  run grep -Eq $'^herdr\tpane\trun\t' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "controller reports a missing Herdr dependency" {
  run env PATH="/usr/bin:/bin" "$CONTROLLER" --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"required command not found: herdr"* ]]
}

@test "controller reports a missing jq dependency" {
  run env PATH="$FAKE_BIN" CALL_LOG="$CALL_LOG" "$CONTROLLER" --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"required command not found: jq"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "dry-run never dispatches or waits" {
  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  run grep -Eq $'^herdr\tpane\t(run|wait-output)\t' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "quiet apply is silent on success" {
  run "$CONTROLLER" --apply --quiet

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$(diagnostic_records)" ]
}

@test "quiet apply suppresses routine cached-client selection output" {
  local cached_client="${XDG_CACHE_HOME}/herdr-refresh/clients/0.7.5-p17/herdr"
  mkdir -p "${cached_client%/*}"
  chmod 700 \
    "$XDG_CACHE_HOME" \
    "${XDG_CACHE_HOME}/herdr-refresh" \
    "${XDG_CACHE_HOME}/herdr-refresh/clients" \
    "${cached_client%/*}"
  cp "$FAKE_BIN/herdr" "$cached_client"
  chmod 700 "$cached_client"

  run env HERDR_COMPATIBLE=no HERDR_SERVER_VERSION=0.7.5 HERDR_SERVER_PROTOCOL=17 \
    HERDR_CLIENT_VERSION=0.7.5 HERDR_CLIENT_PROTOCOL=17 \
    HOME="$HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply --quiet

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "quiet apply preserves nonfatal resolver warnings" {
  local unsafe_cache="${TEST_ROOT}/unsafe-cache"
  local cache_target="${TEST_ROOT}/cache-target"
  mkdir -p "$cache_target"
  ln -s "$cache_target" "$unsafe_cache"

  run env XDG_CACHE_HOME="$unsafe_cache" HOME="$HOME" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --quiet

  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: could not cache Herdr 0.8.2 compatibility client"* ]]
}

@test "quiet apply preserves failure diagnostics" {
  run env FAIL_RUN_PANE=w1:p1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --quiet --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=dispatch-failed"* ]]
  [[ "$output" != *"Mode:"* ]]
  [[ "$output" != *"Summary:"* ]]
}

@test "apply dispatches the worker and acknowledges every eligible pane" {
  run "$CONTROLLER" --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK w1:p1"* ]]
  [[ "$output" == *"refreshed=1"* ]]
  run grep -Eq $'^herdr\tpane\trun\tw1:p1\t.*\.local/bin/zsh-refresh-current.*--ack-file.*--challenge.*&& exec /bin/zsh -l' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Eq $'^herdr\tpane\twait-output\t' "$CALL_LOG"
  [ "$status" -ne 0 ]
  local run_command
  run_command="$(awk -F $'\t' '$2 == "pane" && $3 == "run" { print $5; exit }' "$CALL_LOG")"
  [[ "$run_command" != *"herdr-refresh-ok-"* ]]
  [[ "$run_command" == *"--timeout-ms 12000"* ]]
  [ "$(awk -F $'\t' '$1 == "ack" { print $4; exit }' "$CALL_LOG")" = 700 ]
  run grep -q -- '--clear' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "worker invocation survives a dropped leading command character" {
  local run_command

  run env DROP_LEADING_CHAR_PANE=w1:p1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK w1:p1"* ]]
  run_command="$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { print $5; exit }' "$CALL_LOG")"
  [[ "$run_command" == ' command true 2>/dev/null; '* ]]
}

@test "explicit clear mode passes clear only to the refresh worker" {
  run "$CONTROLLER" --apply --clear

  [ "$status" -eq 0 ]
  run grep -Eq $'^herdr\tpane\trun\tw1:p1\t.*zsh-refresh-current.*--clear.*--ack-file.*--challenge.*&& exec /bin/zsh -l' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "dispatch failure is reported and returns one" {
  run env FAIL_RUN_PANE=w1:p1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=dispatch-failed"* ]]
  [[ "$output" == *"failed=1"* ]]
  run grep -Eq $'^herdr\tpane\twait-output\tw1:p1\t' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "permanent acknowledgement timeout stops after one retry" {
  run env ACK_MODE=timeout PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=acknowledgement-timeout timeout_ms=150 attempts=2"* ]]
  [[ "$output" == *"failed=1"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 2 ]
}

@test "terminal controller failure writes one redacted diagnostic record" {
  local record

  run env ACK_MODE=timeout PRIVATE_ENV_SENTINEL=SECRET-ENVIRONMENT \
    PATH="$PATH" HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --quiet --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=acknowledgement-timeout timeout_ms=150 attempts=2"* ]]
  [[ "$output" == *"saved a redacted failure record; run refresh-doctor"* ]]
  [ "$(diagnostic_records | wc -l | tr -d ' ')" -eq 1 ]
  record="$(diagnostic_records)"
  run jq -e '
    .component == "controller" and
    .reasons == ["acknowledgement-timeout"] and
    .exit_status == 1 and
    .counts.discovered == 2 and
    .counts.eligible == 1 and
    .counts.refreshed == 0 and
    .counts.failed == 1
  ' "$record"
  [ "$status" -eq 0 ]
  run grep -E 'SECRET|pane|command|cwd|environment|stderr|socket|w1:p1' "$record"
  [ "$status" -eq 1 ]
}

@test "apply schema failure writes one infrastructure diagnostic record" {
  local record

  run env PANE_LIST_JSON='{}' PATH="$PATH" HOME="$HOME" \
    XDG_STATE_HOME="$XDG_STATE_HOME" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid pane-list schema"* ]]
  [ "$(diagnostic_records | wc -l | tr -d ' ')" -eq 1 ]
  record="$(diagnostic_records)"
  run jq -e '
    .component == "controller" and
    .reasons == ["pane-schema-invalid"] and
    .exit_status == 2
  ' "$record"
  [ "$status" -eq 0 ]
}

@test "diagnostic writer failure preserves the controller failure" {
  local unsafe_state="${TEST_ROOT}/unsafe-state"
  printf '%s\n' 'not-a-directory' >"$unsafe_state"

  run env ACK_MODE=timeout PATH="$PATH" HOME="$HOME" \
    XDG_STATE_HOME="$unsafe_state" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --quiet --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=acknowledgement-timeout timeout_ms=150 attempts=2"* ]]
  [[ "$output" == *"could not save the redacted failure record"* ]]
}

@test "one transient timeout retries only the unresolved pane" {
  export P2_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'

  run env P2_PROCESS_JSON="$P2_PROCESS_JSON" ACK_FAILURE_PANE=w1:p1 \
    ACK_FAILURE_MODE=timeout ACK_FAILURE_ATTEMPTS=1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [[ "$output" == *"RETRY w1:p1 reason=acknowledgement-timeout timeout_ms=150 attempt=2/2"* ]]
  [[ "$output" == *"refreshed=2"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 2 ]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p2" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 1 ]
}

@test "recovery reuses one idempotent remote command" {
  run env ACK_FAILURE_PANE=w1:p1 ACK_FAILURE_MODE=timeout ACK_FAILURE_ATTEMPTS=1 \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 2 ]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { print $5 }' "$CALL_LOG" | sort -u | wc -l | tr -d ' ')" -eq 1 ]
}

@test "a late valid acknowledgement prevents redispatch" {
  run env ACK_FAILURE_PANE=w1:p1 ACK_FAILURE_MODE=timeout ACK_FAILURE_ATTEMPTS=1 \
    ACK_BEFORE_RETRY_PANE=w1:p1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK w1:p1 recovered=late-acknowledgement"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 1 ]
}

@test "quiet apply is silent after successful recovery" {
  run env ACK_FAILURE_PANE=w1:p1 ACK_FAILURE_MODE=timeout ACK_FAILURE_ATTEMPTS=1 \
    PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --quiet --timeout-ms 150

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "malformed acknowledgement files are rejected" {
  local ack_mode

  for ack_mode in wrong-digest wrong-mode symlink; do
    : >"$CALL_LOG"
    run env ACK_MODE="$ack_mode" PATH="$PATH" CALL_LOG="$CALL_LOG" \
      "$CONTROLLER" --apply --timeout-ms 150

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL w1:p1 reason=acknowledgement-invalid attempts=1"* ]]
    [[ "$output" == *"failed=1"* ]]
    [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 1 ]
  done
}

@test "recovery does not redispatch a pane that stopped being idle" {
  export P1_PROCESS_JSON_THIRD='{"result":{"process_info":{"foreground_processes":[{"name":"node"}]}}}'

  run env ACK_MODE=timeout P1_PROCESS_JSON_THIRD="$P1_PROCESS_JSON_THIRD" \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=changed-before-retry attempts=1"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 1 ]
}

@test "an unacknowledged dispatch error retries once" {
  run env FAIL_RUN_PANE=w1:p1 FAIL_RUN_ATTEMPTS=1 PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 0 ]
  [[ "$output" == *"RETRY w1:p1 reason=dispatch-failed timeout_ms=150 attempt=2/2"* ]]
  [ "$(awk -F $'\t' '$2 == "pane" && $3 == "run" && $4 == "w1:p1" { count += 1 } END { print count + 0 }' "$CALL_LOG")" -eq 2 ]
}

@test "one pane failure does not prevent attempts in other eligible panes" {
  export P2_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'

  run env FAIL_RUN_PANE=w1:p1 P2_PROCESS_JSON="$P2_PROCESS_JSON" PATH="$PATH" CALL_LOG="$CALL_LOG" \
    "$CONTROLLER" --apply --timeout-ms 150

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1"* ]]
  [[ "$output" == *"OK w1:p2"* ]]
  [[ "$output" == *"eligible=2"* ]]
  [[ "$output" == *"refreshed=1"* ]]
  [[ "$output" == *"failed=1"* ]]
}

@test "apply rechecks eligibility immediately before dispatch" {
  export P1_PROCESS_JSON_SECOND='{"result":{"process_info":{"foreground_processes":[{"name":"node"}]}}}'

  run env P1_PROCESS_JSON_SECOND="$P1_PROCESS_JSON_SECOND" PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=changed-before-dispatch"* ]]
  run grep -Eq $'^herdr\tpane\trun\tw1:p1\t' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "recheck infrastructure failure remains distinguishable" {
  run env FAIL_PROCESS_PANE_SECOND=w1:p1 PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 1 ]
  [[ "$output" == *"SKIP w1:p1 reason=process-info-unavailable-before-dispatch"* ]]
  run grep -Eq $'^herdr\tpane\trun\tw1:p1\t' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "every eligible pane receives a unique acknowledgement" {
  export P2_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'

  run env P2_PROCESS_JSON="$P2_PROCESS_JSON" PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 0 ]
  [ "$(awk -F $'\t' '$1 == "ack" { print $3 }' "$CALL_LOG" | sort -u | wc -l | tr -d ' ')" -eq 2 ]
  [ "$(awk -F $'\t' '$1 == "ack" { sub("/ack-[^/]+$", "", $3); print $3 }' "$CALL_LOG" | sort -u | wc -l | tr -d ' ')" -eq 1 ]
}

@test "acknowledgement waits run concurrently" {
  local wait_gate="${TEST_ROOT}/wait-gate"
  mkdir -p "$wait_gate"
  export P2_PROCESS_JSON='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'

  run env P2_PROCESS_JSON="$P2_PROCESS_JSON" WAIT_GATE_DIR="$wait_gate" WAIT_FOR_PEERS=2 \
    PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"refreshed=2"* ]]
  [ "$(find "$wait_gate" -maxdepth 1 -type f | wc -l | tr -d ' ')" -eq 2 ]
  run grep -Eq $'^herdr\tpane\twait-output\t' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "clear-only uses a fixed command and does not replace the remote shell" {
  run "$CONTROLLER" --apply --clear-only

  [ "$status" -eq 0 ]
  run grep -Eq $'^herdr\tpane\trun\tw1:p1\t.*zsh-refresh-current.*--clear-only.*--ack-file.*--challenge' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -q '&& exec /bin/zsh -l' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "invalid timeout fails before Herdr discovery" {
  run "$CONTROLLER" --timeout-ms 99 --apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid timeout"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "apply rejects a missing worker before Herdr discovery" {
  local empty_home="${TEST_ROOT}/empty-home"
  mkdir -p "$empty_home"

  run env HOME="$empty_home" PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"worker is unavailable"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "controller rejects a missing compatibility resolver before discovery" {
  local empty_home="${TEST_ROOT}/empty-home"
  mkdir -p "$empty_home"

  run env HOME="$empty_home" PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"compatibility resolver is unavailable"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "worker paths containing spaces remain one safely quoted command" {
  local spaced_home="${TEST_ROOT}/home with space"
  mkdir -p "$spaced_home/.local/bin" "$spaced_home/.local/libexec"
  printf '%s\n' '#!/bin/bash' 'exit 0' >"$spaced_home/.local/bin/zsh-refresh-current"
  chmod +x "$spaced_home/.local/bin/zsh-refresh-current"
  install -m 700 "$RESOLVER" "$spaced_home/.local/libexec/herdr-refresh-client"

  run env HOME="$spaced_home" PATH="$PATH" CALL_LOG="$CALL_LOG" "$CONTROLLER" --apply

  [ "$status" -eq 0 ]
  local run_command
  run_command="$(awk -F $'\t' '$2 == "pane" && $3 == "run" { print $5; exit }' "$CALL_LOG")"
  [[ "$run_command" == *'home\ with\ space/.local/bin/zsh-refresh-current'* ]]
}

@test "refresh-dry previews the default clear policy and checks the current shell" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; refresh-dry'

  [ "$status" -eq 0 ]
  run grep -Fx $'controller\t--dry-run\t--clear\t--exclude-pane\tw1:p1' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx $'worker\t--check' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "refresh-dry validates and forwards a custom acknowledgement timeout" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; refresh-dry --timeout-ms 250'

  [ "$status" -eq 0 ]
  run grep -Fx $'controller\t--dry-run\t--timeout-ms\t250\t--clear\t--exclude-pane\tw1:p1' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx $'worker\t--check' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "refresh-dry failure never writes a persistent diagnostic" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" \
    CALL_LOG="$CALL_LOG" PATH="$PATH" FAIL_WORKER=1 \
    /bin/zsh -f -c 'source "$MODULE"; refresh-dry'

  [ "$status" -eq 1 ]
  run grep -q '^doctor' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "refresh applies default clear before replacing the current shell" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; _herdr_refresh_exec_shell() { printf "exec-shell\n" >>"$CALL_LOG"; }; refresh'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(sed -n '1p' "$CALL_LOG")" = $'controller\t--apply\t--quiet\t--clear\t--exclude-pane\tw1:p1' ]
  [ "$(sed -n '2p' "$CALL_LOG")" = $'worker\t--clear' ]
  [ "$(sed -n '3p' "$CALL_LOG")" = 'exec-shell' ]
}

@test "refresh keep-scrollback preserves successful output" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; _herdr_refresh_exec_shell() { printf "exec-shell\n" >>"$CALL_LOG"; }; refresh --keep-scrollback'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(sed -n '1p' "$CALL_LOG")" = $'controller\t--apply\t--quiet\t--exclude-pane\tw1:p1' ]
  [ "$(sed -n '2p' "$CALL_LOG")" = 'worker' ]
  [ "$(sed -n '3p' "$CALL_LOG")" = 'exec-shell' ]
}

@test "refresh rejects conflicting clear policies before execution" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; refresh --clear --keep-scrollback'

  [ "$status" -eq 2 ]
  [[ "$output" == *"cannot be combined"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "refresh stops before the current shell when a remote refresh fails" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" FAIL_CONTROLLER=1 \
    /bin/zsh -f -c 'source "$MODULE"; refresh'

  [ "$status" -eq 1 ]
  run grep -q '^worker' "$CALL_LOG"
  [ "$status" -ne 0 ]
  run grep -q '^doctor' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "refresh clear flag remains compatible for remote and current panes" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; _herdr_refresh_exec_shell() { printf "exec-shell\n" >>"$CALL_LOG"; }; refresh --clear'

  [ "$status" -eq 0 ]
  run grep -Fx $'controller\t--apply\t--quiet\t--clear\t--exclude-pane\tw1:p1' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx $'worker\t--clear' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "failed current preflight preserves the invoking shell" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" FAIL_WORKER=1 \
    /bin/zsh -f -c 'source "$MODULE"; refresh; refresh_status=$?; print -r -- "caller-survived"; exit $refresh_status'

  [ "$status" -eq 1 ]
  [[ "$output" == *"caller-survived"* ]]
  [[ "$output" == *"saved a redacted failure record; run refresh-doctor"* ]]
  run grep -q '^exec-shell' "$CALL_LOG"
  [ "$status" -ne 0 ]
  run grep -Fx $'doctor\t--record\t--component\tcurrent-shell\t--reason\tcurrent-shell-refresh-failed\t--exit-status\t1' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "local diagnostic writer failure preserves the worker status" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" \
    CALL_LOG="$CALL_LOG" PATH="$PATH" FAIL_WORKER=1 FAIL_DIAGNOSTIC_WRITER=1 \
    /bin/zsh -f -c 'source "$MODULE"; refresh'

  [ "$status" -eq 1 ]
  [[ "$output" == *"could not save the redacted failure record"* ]]
}

@test "clear-panes keeps clear-only compatibility without replacing shells" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" HERDR_PANE_ID=w1:p1 MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" TERM=xterm-256color \
    /bin/zsh -f -c 'source "$MODULE"; clear-panes'

  [ "$status" -eq 0 ]
  run grep -Fx $'controller\t--apply\t--quiet\t--clear-only\t--exclude-pane\tw1:p1' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx 'clear' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -q '^worker' "$CALL_LOG"
  [ "$status" -ne 0 ]
}

@test "refresh help and invalid options never contact Herdr" {
  make_fake_refresh_commands

  run env HOME="$TEST_HOME" MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; refresh --help'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--keep-scrollback"* ]]
  [ ! -s "$CALL_LOG" ]

  run env HOME="$TEST_HOME" MODULE="$MODULE" CALL_LOG="$CALL_LOG" PATH="$PATH" \
    /bin/zsh -f -c 'source "$MODULE"; refresh --unknown'
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown argument"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "refresh refuses running jobs before touching any pane or clearing" {
  make_fake_refresh_commands
  run /bin/zsh -f -c '
    source "$MODULE"
    _herdr_refresh_exec_shell() { print exec-shell >>"$CALL_LOG"; }
    /bin/sleep 30 >/dev/null 2>&1 & fixture_job=$!
    refresh; refresh_result=$?
    zmodload zsh/parameter
    print -r -- "preserved:${#jobstates}"
    kill $fixture_job; wait $fixture_job 2>/dev/null
    exit $refresh_result'
  [ "$status" -eq 75 ]
  [[ "$output" == *"pending jobs"* ]]
  [[ "$output" == *"preserved:1"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "refresh refuses stopped jobs repeatedly without losing the job table" {
  make_fake_refresh_commands
  run /bin/zsh -f -c '
    source "$MODULE"
    _herdr_refresh_exec_shell() { print exec-shell >>"$CALL_LOG"; }
    /bin/sleep 30 >/dev/null 2>&1 & fixture_job=$!
    kill -STOP $fixture_job; /bin/sleep 0.05
    refresh; first_result=$?
    refresh --keep-scrollback; second_result=$?
    zmodload zsh/parameter
    print -r -- "preserved:${#jobstates}:$first_result:$second_result"
    kill -CONT $fixture_job; kill $fixture_job; wait $fixture_job 2>/dev/null
    exit $second_result'
  [ "$status" -eq 75 ]
  [[ "$output" == *"preserved:1:75:75"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "refresh-dry remains available with pending jobs" {
  make_fake_refresh_commands
  run /bin/zsh -f -c '
    source "$MODULE"
    /bin/sleep 30 >/dev/null 2>&1 & fixture_job=$!
    refresh-dry; refresh_result=$?
    kill $fixture_job; wait $fixture_job 2>/dev/null
    exit $refresh_result'
  [ "$status" -eq 0 ]
  run grep -Fx $'worker\t--check' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -E 'exec-shell|--apply|worker.*--clear' "$CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "remote pending jobs are skipped without timeout retry or shell replacement" {
  local job_state
  for job_state in running stopped; do
    : >"$CALL_LOG"
    run env REMOTE_JOB_STATE="$job_state" "$CONTROLLER" --apply --quiet --clear --timeout-ms 500
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP w1:p1 reason=pending-jobs"* ]]
    [[ "$output" != *"RETRY"* ]]
    [ "$(grep -c $'^herdr\tpane\trun' "$CALL_LOG")" -eq 1 ]
    run grep -Fx 'survived:75:1' "$CALL_LOG"
    [ "$status" -eq 0 ]
    run grep -Fx clear "$CALL_LOG"
    [ "$status" -eq 1 ]
  done
}

@test "worker pending-job refusal is bound to its acknowledgement challenge" {
  local ack_dir="${TEST_ROOT}/job-acks"
  mkdir -m 700 "$ack_dir"
  run "$WORKER" --shell-job-count 1 --clear --ack-file "$ack_dir/ack" --challenge refresh:jobs
  [ "$status" -eq 75 ]
  [[ "$output" == *"pending jobs"* ]]
  [ "$(cat "$ack_dir/ack")" = "pending-jobs:$(printf %s refresh:jobs | shasum -a 256 | awk '{print $1}')" ]
  [ "$(file_mode "$ack_dir/ack")" = 600 ]
  [ ! -s "$CALL_LOG" ]
}

@test "refresh rechecks jobs created by a trap during controller or preflight" {
  make_fake_refresh_commands
  local phase
  for phase in controller worker; do
    : >"$CALL_LOG"
    run env JOBS_DURING="$phase" /bin/zsh -f -c '
      source "$MODULE"
      TRAPUSR1() { /bin/sleep 30 >/dev/null 2>&1 & fixture_job=$!; unfunction TRAPUSR1; }
      export CALLER_PID=$$
      refresh; refresh_result=$?
      print -r -- caller-survived
      kill $fixture_job; wait $fixture_job 2>/dev/null
      exit $refresh_result'
    [ "$status" -eq 75 ]
    [[ "$output" == *"caller-survived"* ]]
    [[ "$output" == *"pending jobs"* ]]
    if [[ "$phase" == controller ]]; then
      run grep '^worker' "$CALL_LOG"
      [ "$status" -eq 1 ]
    fi
  done
}

@test "worker rejects malformed shell job counts before any work" {
  local value
  for value in '' -1 nonsense '0;true'; do
    run "$WORKER" --shell-job-count "$value" --clear
    [ "$status" -eq 2 ]
    [ ! -s "$CALL_LOG" ]
  done
}

@test "remote refresh refuses a job created during startup preflight before acknowledging success" {
  printf '%s\n' '#!/bin/bash' 'printf "clear\n" >>"$CALL_LOG"' >"$FAKE_BIN/clear"
  chmod +x "$FAKE_BIN/clear"
  make_isolated_zdotdir "$TEST_HOME"
  printf '%s\n' 'kill -USR1 "$CALLER_PID"' >"$TEST_HOME/.zshrc"
  run env REMOTE_JOB_STATE=late ZDOTDIR="$TEST_HOME" "$CONTROLLER" --apply --clear --timeout-ms 2000
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=pending-jobs"* ]]
  [[ "$output" != *"OK w1:p1"* ]]
  run grep -Fx 'survived:75:1' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -Fx clear "$CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "remote refresh with no jobs still validates acknowledges and replaces the shell" {
  make_isolated_zdotdir "$TEST_HOME"
  run env REMOTE_JOB_STATE=clean ZDOTDIR="$TEST_HOME" "$CONTROLLER" --apply --timeout-ms 2000
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK w1:p1"* ]]
  run grep -F survived "$CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "worker prepares without clearing or publishing success then finishes once" {
  make_isolated_zdotdir "$TEST_HOME"
  printf '%s\n' 'printf "startup\n" >>"$CALL_LOG"' >"$TEST_HOME/.zshrc"
  printf '%s\n' '#!/bin/bash' 'printf "clear\n" >>"$CALL_LOG"' >"$FAKE_BIN/clear"
  chmod +x "$FAKE_BIN/clear"
  local ack_dir="${TEST_ROOT}/phase-acks"
  mkdir -m 700 "$ack_dir"
  run env ZDOTDIR="$TEST_HOME" "$WORKER" --refresh-phase prepare --shell-job-count 0 \
    --clear --ack-file "$ack_dir/ack" --challenge refresh:phases
  [ "$status" -eq 0 ]
  [ ! -e "$ack_dir/ack" ]
  [ "$(cat "$CALL_LOG")" = startup ]
  run "$WORKER" --refresh-phase finish --shell-job-count 0 \
    --clear --ack-file "$ack_dir/ack" --challenge refresh:phases
  [ "$status" -eq 0 ]
  [ "$(cat "$CALL_LOG")" = $'startup\nclear' ]
  [ "$(cat "$ack_dir/ack")" = "$(printf %s refresh:phases | shasum -a 256 | awk '{print $1}')" ]
  run "$WORKER" --refresh-phase finish --clear \
    --ack-file "$ack_dir/ack" --challenge refresh:phases
  [ "$status" -eq 2 ]
  [ "$(cat "$CALL_LOG")" = $'startup\nclear' ]
}

@test "worker rejects invalid or unbound refresh phases" {
  local phase
  for phase in '' nope prepare finish; do
    run "$WORKER" --refresh-phase "$phase" --clear
    [ "$status" -eq 2 ]
    [ ! -s "$CALL_LOG" ]
  done
}

@test "refresh sources the latest module once and immediately uses its new implementation" {
  make_fake_refresh_commands
  cat >>"$TEST_HOME/.zshrc.d/herdr-refresh.zsh" <<'ZSH'
print -r -- module-reloaded >>"$CALL_LOG"
_herdr_refresh_run() {
  print -r -- "$#|$1|$2|$3" >>"$CALL_LOG"
  return 37
}
ZSH
  run /bin/zsh -f -c 'source "$MODULE"; refresh --keep-scrollback --timeout-ms 250'
  [ "$status" -eq 37 ]
  [ "$(cat "$CALL_LOG")" = $'module-reloaded\n3|--keep-scrollback|--timeout-ms|250' ]
}

@test "refresh reloads only its module on each read-only preview" {
  make_fake_refresh_commands
  printf '%s\n' 'print -r -- module-reloaded >>"$CALL_LOG"' >>"$TEST_HOME/.zshrc.d/herdr-refresh.zsh"
  printf '%s\n' 'print -r -- unexpected-zshrc >>"$CALL_LOG"' >"$TEST_HOME/.zshrc"
  run /bin/zsh -f -c 'source "$MODULE"; refresh-dry; refresh-dry'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^module-reloaded$' "$CALL_LOG")" -eq 2 ]
  [ "$(grep -c $'^worker\t--check$' "$CALL_LOG")" -eq 2 ]
  run grep -E 'unexpected-zshrc|exec-shell|--apply|worker.*--clear' "$CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "refresh rejects a missing or malformed module without changing panes" {
  make_fake_refresh_commands
  rm "$TEST_HOME/.zshrc.d/herdr-refresh.zsh"
  run /bin/zsh -f -c 'source "$MODULE"; refresh'
  [ "$status" -eq 1 ]
  [[ "$output" == *"refresh module is unavailable"* ]]
  [ ! -s "$CALL_LOG" ]
  printf '%s\n' 'print unexpected >>"$CALL_LOG"' 'if then' >"$TEST_HOME/.zshrc.d/herdr-refresh.zsh"
  run /bin/zsh -f -c 'source "$MODULE"; refresh'
  [ "$status" -eq 1 ]
  [[ "$output" == *"refresh module has invalid syntax"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "refresh stops on source failure or missing implementation instead of using stale code" {
  make_fake_refresh_commands
  printf '%s\n' 'return 23' >"$TEST_HOME/.zshrc.d/herdr-refresh.zsh"
  run /bin/zsh -f -c 'source "$MODULE"; refresh'
  [ "$status" -eq 23 ]
  [[ "$output" == *"could not load refresh module"* ]]
  [ ! -s "$CALL_LOG" ]
  : >"$TEST_HOME/.zshrc.d/herdr-refresh.zsh"
  run /bin/zsh -f -c 'source "$MODULE"; refresh'
  [ "$status" -eq 1 ]
  [[ "$output" == *"refresh implementation is unavailable"* ]]
  [ ! -s "$CALL_LOG" ]
}

# Start a real parent/child pair standing in for a pane shell and its job.
# Bash and Zsh without job control resume a stopped child they own, so the
# parent is a small Perl process that only waits; the child stops itself.
start_fixture_child() {
  local state="$1" pid_file="${TEST_ROOT}/fixture-child.pid" attempts=0
  /usr/bin/perl -e '
    my ($state, $pid_file) = @ARGV;
    my $child = fork;
    die "fork failed\n" unless defined $child;
    if ($child == 0) {
      kill "STOP", $$ if $state eq "stopped";
      exec "/bin/sleep", "30";
    }
    open my $fh, ">", "$pid_file.tmp" or die;
    print $fh "$child\n";
    close $fh;
    rename "$pid_file.tmp", $pid_file or die;
    waitpid $child, 0;
  ' "$state" "$pid_file" >/dev/null 2>&1 3>&- &
  FIXTURE_SHELL_PID=$!
  FIXTURE_PIDS="${FIXTURE_PIDS:-} $FIXTURE_SHELL_PID"
  until [[ -s "$pid_file" ]]; do
    (( ++attempts < 100 )) || return 1
    /bin/sleep 0.02
  done
  FIXTURE_CHILD_PID="$(<"$pid_file")"
  FIXTURE_PIDS="${FIXTURE_PIDS} $FIXTURE_CHILD_PID"
  [[ "$state" == stopped ]] || return 0
  attempts=0
  until /bin/ps -o stat= -p "$FIXTURE_CHILD_PID" | grep -q '^T'; do
    (( ++attempts < 100 )) || return 1
    /bin/sleep 0.02
  done
}

idle_zsh_process_json() {
  printf '{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","shell_pid":%s,"foreground_processes":[{"name":"zsh"}]}}}' "$1"
}

@test "apply skips a shell with a stopped job before dispatching to it" {
  start_fixture_child stopped
  export P1_PROCESS_JSON="$(idle_zsh_process_json "$FIXTURE_SHELL_PID")"
  export PANE_LIST_JSON='{"result":{"panes":[{"pane_id":"w1:p1","label":"update-all --no-stamps"},{"pane_id":"w1:p2"}]}}'

  run "$CONTROLLER" --apply --quiet --clear --timeout-ms 500

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=stopped-job pid=${FIXTURE_CHILD_PID} label=\"update-all --no-stamps\""* ]]
  [[ "$output" == *"jobs -l"* ]]
  run grep -c $'^herdr\tpane\trun' "$CALL_LOG"
  [ "$output" = 0 ]
  [ -z "$(diagnostic_records)" ]
}

@test "dry-run reports a stopped job instead of calling the pane eligible" {
  start_fixture_child stopped
  export P1_PROCESS_JSON="$(idle_zsh_process_json "$FIXTURE_SHELL_PID")"

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=stopped-job pid=${FIXTURE_CHILD_PID}"* ]]
  [[ "$output" != *"ELIGIBLE w1:p1"* ]]
  [[ "$output" == *"skipped=2"* ]]
}

@test "a running background child is left to the owning shell's job gate" {
  start_fixture_child running
  export P1_PROCESS_JSON="$(idle_zsh_process_json "$FIXTURE_SHELL_PID")"

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"ELIGIBLE w1:p1"* ]]
  [[ "$output" != *"stopped-job"* ]]
}

@test "absent or malformed shell_pid falls back to the owning shell's job gate" {
  start_fixture_child stopped
  local shell_pid_field
  for shell_pid_field in '' ',"shell_pid":"'"$FIXTURE_SHELL_PID"'"' ',"shell_pid":0' ',"shell_pid":1' ',"shell_pid":1.5' ',"shell_pid":null'; do
    : >"$CALL_LOG"
    export P1_PROCESS_JSON='{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1"'"$shell_pid_field"',"foreground_processes":[{"name":"zsh"}]}}}'
    run "$CONTROLLER" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"ELIGIBLE w1:p1"* ]]
  done
}

@test "a job stopped after inspection is skipped at the pre-dispatch recheck" {
  start_fixture_child stopped
  export P1_PROCESS_JSON='{"result":{"type":"pane_process_info","process_info":{"pane_id":"w1:p1","foreground_processes":[{"name":"zsh"}]}}}'
  export P1_PROCESS_JSON_SECOND="$(idle_zsh_process_json "$FIXTURE_SHELL_PID")"

  run "$CONTROLLER" --apply --quiet --timeout-ms 500

  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP w1:p1 reason=stopped-job pid=${FIXTURE_CHILD_PID}"* ]]
  run grep -c $'^herdr\tpane\trun' "$CALL_LOG"
  [ "$output" = 0 ]
}

@test "job skip labels are bounded and cannot carry terminal control sequences" {
  start_fixture_child stopped
  export P1_PROCESS_JSON="$(idle_zsh_process_json "$FIXTURE_SHELL_PID")"
  export PANE_LIST_JSON='{"result":{"panes":[{"pane_id":"w1:p1","label":"a\u001b]0;pwn\u0007b\"c\\d\u009beeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}]}}'

  run "$CONTROLLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *'label="a?]0;pwn?b\"c\\d?eeeeeeeeeeeeeeeeeeeeeeeee"'* ]]
  # Only newline, tab, and printable ASCII may remain in the skip report.
  [ "$(printf '%s' "$output" | LC_ALL=C tr -d '\n\t -~' | wc -c | tr -d ' ')" = 0 ]
}

@test "a pane without a label falls back to its terminal title, then to no label" {
  start_fixture_child stopped
  export P1_PROCESS_JSON="$(idle_zsh_process_json "$FIXTURE_SHELL_PID")"
  export PANE_LIST_JSON='{"result":{"panes":[{"pane_id":"w1:p1","terminal_title_stripped":"caffeinate -dims"}]}}'
  run "$CONTROLLER" --dry-run
  [[ "$output" == *'reason=stopped-job pid='*' label="caffeinate -dims"'* ]]

  export PANE_LIST_JSON='{"result":{"panes":[{"pane_id":"w1:p1","label":""}]}}'
  run "$CONTROLLER" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"reason=stopped-job pid="* ]]
  [[ "$output" != *"label="* ]]
}

@test "remote pending-job skips name the pane label and the next step" {
  export PANE_LIST_JSON='{"result":{"panes":[{"pane_id":"w1:p1","label":"long build"}]}}'
  run env REMOTE_JOB_STATE=running "$CONTROLLER" --apply --quiet --timeout-ms 500
  [ "$status" -eq 0 ]
  [[ "$output" == *'SKIP w1:p1 reason=pending-jobs label="long build"'*"jobs -l"* ]]
}

@test "local refusal lists the blocking jobs and how to clear them" {
  make_fake_refresh_commands
  run /bin/zsh -f -c '
    source "$MODULE"
    /bin/sleep 31 >/dev/null 2>&1 & fixture_job=$!
    kill -STOP $fixture_job; /bin/sleep 0.05
    refresh; refresh_result=$?
    kill -CONT $fixture_job; kill $fixture_job; wait $fixture_job 2>/dev/null
    exit $refresh_result'
  [ "$status" -eq 75 ]
  [[ "$output" == *"pending jobs"* ]]
  [[ "$output" == *"sleep 31"* ]]
  [[ "$output" == *"fg"*"kill %"* ]]
  [ ! -s "$CALL_LOG" ]
}

@test "refresh-dry warns that this shell's jobs would stop a real refresh" {
  make_fake_refresh_commands
  run /bin/zsh -f -c '
    source "$MODULE"
    /bin/sleep 32 >/dev/null 2>&1 & fixture_job=$!
    refresh-dry; refresh_result=$?
    kill $fixture_job; wait $fixture_job 2>/dev/null
    exit $refresh_result'
  [ "$status" -eq 0 ]
  [[ "$output" == *"this shell has 1 pending job"*"refresh would stop here"* ]]
  [[ "$output" == *"sleep 32"* ]]
  run grep -Fx $'worker\t--check' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "remote worker refusal tells the pane owner how to clear its jobs" {
  local ack_dir="${TEST_ROOT}/hint-acks"
  mkdir -m 700 "$ack_dir"
  run "$WORKER" --shell-job-count 2 --ack-file "$ack_dir/ack" --challenge refresh:hint
  [ "$status" -eq 75 ]
  [[ "$output" == *"pending jobs"*"jobs -l"*"fg"*"kill %"* ]]
}

@test "worker check normalizes dumb or empty TERM for startup preflight" {
  local zdotdir="${TEST_ROOT}/dumb-term-zdot"
  make_isolated_zdotdir "$zdotdir"
  cat >"${zdotdir}/.zshrc" <<'ZSH'
if [[ "${TERM:-}" == "dumb" || -z "${TERM:-}" ]]; then
  print -u2 -r -- "starship/autocomplete fails under dumb terminal"
  return 1
fi
ZSH

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" TERM=dumb "$WORKER" --check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "remote prepare failure acknowledges preflight-failed and fails without timeout retry" {
  local zdotdir="${TEST_ROOT}/prepare-fail-zdot"
  make_isolated_zdotdir "$zdotdir"
  printf '%s\n' 'if then' >"${zdotdir}/.zshrc"

  run env REMOTE_JOB_STATE=clean ZDOTDIR="$zdotdir" "$CONTROLLER" --apply --timeout-ms 2000

  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL w1:p1 reason=startup-preflight-failed"* ]]
  run grep -c $'^herdr\tpane\trun\tw1:p1\t' "$CALL_LOG"
  [ "$output" = 1 ]
}

@test "worker check succeeds inside a Herdr pane when herdr-sidebar-context module loads" {
  local zdotdir="${TEST_ROOT}/sidebar-context-zdot"
  make_isolated_zdotdir "$zdotdir"
  mkdir -p "${zdotdir}/.zshrc.d"
  cp "$MODULE_LOADER_SOURCE" "${zdotdir}/.zshrc.d/.module-loader.zsh"
  cp "${TS_SOURCE_ROOT}/dot_zshrc.d/herdr-sidebar-context.zsh" "${zdotdir}/.zshrc.d/herdr-sidebar-context.zsh"
  printf '%s\n' herdr-sidebar-context.zsh >"${zdotdir}/.zshrc.d/.module-order"
  printf '%s\n' \
    'source "$ZDOTDIR/.zshrc.d/.module-loader.zsh"' \
    'terminal_load_zsh_modules "$ZDOTDIR/.zshrc.d" "$ZDOTDIR/.zshrc.d/.module-order"' \
    >"${zdotdir}/.zshrc"

  run env HOME="$TEST_HOME" ZDOTDIR="$zdotdir" HERDR_ENV=1 HERDR_PANE_ID=w0:p4 "$WORKER" --check

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -s "$CALL_LOG" ]
}

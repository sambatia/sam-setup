#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
config_root=$(dirname "$script_dir")
updater="$config_root/scripts/safe-plugin-update.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/lazyvim-updater-tests.XXXXXX")
original_path=$PATH

cleanup() {
  case "$test_root" in
    "${TMPDIR:-/tmp}"/lazyvim-updater-tests.*) rm -rf "$test_root" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

create_case() {
  case_name=$1
  case_root="$test_root/$case_name"
  case_config="$case_root/repo/nvim"
  case_state="$case_root/state"
  case_backup="$case_root/nvim.backup.baseline"
  case_bin="$case_root/bin"
  case_calls="$case_root/nvim-calls.log"
  case_restore_marker="$case_root/restore-complete"

  mkdir -p "$case_config" "$case_backup" "$case_bin"
  printf '%s\n' '{"plugin":{"branch":"main","commit":"abc"}}' > "$case_config/lazy-lock.json"
  mkdir "$case_config/lua" "$case_backup/lua"
  printf '%s\n' 'return true' > "$case_config/init.lua"
  cp "$case_config/lazy-lock.json" "$case_backup/lazy-lock.json"
  cp "$case_config/init.lua" "$case_backup/init.lua"
  git -C "$case_root/repo" init -q
  git -C "$case_root/repo" config user.email "updater-test@example.invalid"
  git -C "$case_root/repo" config user.name "Updater Test"
  git -C "$case_root/repo" add nvim/init.lua nvim/lazy-lock.json
  git -C "$case_root/repo" commit -qm "test baseline"

  # These single-quoted lines intentionally defer expansion to the generated
  # fake executable.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'printf "%s\n" "$*" >> "$FAKE_NVIM_LOG"' \
    'case "$*" in' \
    '  *"Lazy! update"*) printf "%s\n" "{\"updated\":true}" > "$NVIM_SAFE_UPDATE_CONFIG_DIR/lazy-lock.json" ;;' \
    'esac' \
    'case "$*" in' \
    '  *"Lazy! restore"*) : > "$FAKE_NVIM_RESTORE_MARKER" ;;' \
    'esac' \
    'case "$*" in' \
    '  *"Lazy! sync"*) [ "${FAKE_NVIM_FAIL_SYNC:-0}" = "1" ] && exit 9 ;;' \
    'esac' \
    'case "$*" in' \
    '  *"verify-treesitter.lua"*)' \
    '    if [ "${FAKE_NVIM_FAIL_PARSERS:-0}" = "1" ] && [ ! -e "$FAKE_NVIM_RESTORE_MARKER" ]; then exit 10; fi' \
    '    ;;' \
    'esac' \
    'case "$*" in' \
    '  *"assert_no_errors"*) [ "${FAKE_NVIM_FAIL_HEALTH:-0}" = "1" ] && exit 11 ;;' \
    'esac' \
    'case "$*" in' \
    '  *"--headless -l "*"tests/runtime_smoke.lua"*) exit 14 ;;' \
    'esac' \
    'case "$*" in' \
    '  *"tests/runtime_smoke.lua"*) [ "${FAKE_NVIM_FAIL_RUNTIME:-0}" = "1" ] && exit 12 ;;' \
    'esac' \
    'case "$*" in' \
    '  *"checkhealth codecompanion"*) [ "${FAKE_NVIM_FAIL_CODECOMPANION_HEALTH:-0}" = "1" ] && exit 13 ;;' \
    'esac' \
    'exit 0' > "$case_bin/nvim"
  chmod +x "$case_bin/nvim"

  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/bin/sh' \
    '[ "${FAKE_NVIM_RUNNING:-0}" = "1" ]' > "$case_bin/pgrep"
  chmod +x "$case_bin/pgrep"

  export NVIM_SAFE_UPDATE_CONFIG_DIR="$case_config"
  export NVIM_SAFE_UPDATE_STATE_DIR="$case_state"
  export NVIM_SAFE_UPDATE_BASELINE_BACKUP="$case_backup"
  export NVIM_SAFE_UPDATE_NVIM="$case_bin/nvim"
  export FAKE_NVIM_LOG="$case_calls"
  export FAKE_NVIM_RESTORE_MARKER="$case_restore_marker"
  export PATH="$case_bin:$original_path"
  unset FAKE_NVIM_FAIL_SYNC
  unset FAKE_NVIM_FAIL_PARSERS
  unset FAKE_NVIM_FAIL_HEALTH
  unset FAKE_NVIM_FAIL_RUNTIME
  unset FAKE_NVIM_FAIL_CODECOMPANION_HEALTH
  unset FAKE_NVIM_RUNNING
  unset NVIM_SAFE_UPDATE_PARENT_PID
}

assert_file_contains() {
  file=$1
  expected=$2
  if ! grep -F "$expected" "$file" >/dev/null; then
    printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
    exit 1
  fi
}

if [ ! -x "$updater" ]; then
  printf 'Updater is missing or not executable: %s\n' "$updater" >&2
  exit 1
fi

create_case dry_run
"$updater" --manual --dry-run
[ ! -e "$case_calls" ]
[ ! -e "$case_state" ]

create_case lock_rejection
mkdir -p "$case_state/update.lock"
printf '%s\n' "$$" > "$case_state/update.lock/pid"
set +e
"$updater" --manual
lock_status=$?
set -e
[ "$lock_status" -eq 75 ]
[ ! -e "$case_calls" ]

create_case session_rejection
export FAKE_NVIM_RUNNING=1
set +e
"$updater" --manual
session_status=$?
set -e
[ "$session_status" -eq 75 ]
[ ! -e "$case_calls" ]
[ ! -e "$case_state" ]

create_case success
"$updater" --manual
jq -e '.status == "success" and .rolled_back == false' "$case_state/last-result.json" >/dev/null
[ -s "$case_state/last-attempt" ]
[ -s "$case_state/last-success" ]
snapshot=$(find "$case_state/snapshots" -type f -name 'lazy-lock.*.json' -print -quit)
[ -n "$snapshot" ]
assert_file_contains "$snapshot" '"commit":"abc"'
assert_file_contains "$case_config/lazy-lock.json" '"updated":true'
assert_file_contains "$case_calls" 'Lazy! update'
assert_file_contains "$case_calls" 'Lazy! sync'
assert_file_contains "$case_calls" 'verify-treesitter.lua'
assert_file_contains "$case_calls" 'assert_no_errors'
assert_file_contains "$case_calls" 'tests/runtime_smoke.lua'
assert_file_contains "$case_calls" 'checkhealth codecompanion'

create_case rollback
export FAKE_NVIM_FAIL_SYNC=1
set +e
"$updater" --manual
rollback_status=$?
set -e
[ "$rollback_status" -ne 0 ]
jq -e '.status == "failed" and .rolled_back == true' "$case_state/last-result.json" >/dev/null
assert_file_contains "$case_config/lazy-lock.json" '"commit":"abc"'
assert_file_contains "$case_calls" 'Lazy! restore'
[ ! -e "$case_state/update.lock" ]
[ ! -e "$case_state/last-success" ]

create_case parser_rollback
export FAKE_NVIM_FAIL_PARSERS=1
set +e
"$updater" --manual
parser_status=$?
set -e
[ "$parser_status" -ne 0 ]
jq -e '.status == "failed" and .rolled_back == true' "$case_state/last-result.json" >/dev/null
assert_file_contains "$case_config/lazy-lock.json" '"commit":"abc"'
assert_file_contains "$case_calls" 'verify-treesitter.lua'
assert_file_contains "$case_calls" 'Lazy! restore'
parser_checks=$(grep -Fc 'verify-treesitter.lua' "$case_calls")
[ "$parser_checks" -eq 2 ]
restore_line=$(grep -n -F 'Lazy! restore' "$case_calls" | tail -1 | cut -d: -f1)
parser_line=$(grep -n -F 'verify-treesitter.lua' "$case_calls" | tail -1 | cut -d: -f1)
[ "$parser_line" -gt "$restore_line" ]

create_case health_rollback
export FAKE_NVIM_FAIL_HEALTH=1
set +e
"$updater" --manual
health_status=$?
set -e
[ "$health_status" -ne 0 ]
jq -e '.status == "failed" and .rolled_back == true' "$case_state/last-result.json" >/dev/null
assert_file_contains "$case_config/lazy-lock.json" '"commit":"abc"'
assert_file_contains "$case_calls" 'assert_no_errors'
assert_file_contains "$case_calls" 'Lazy! restore'

create_case runtime_rollback
export FAKE_NVIM_FAIL_RUNTIME=1
set +e
"$updater" --manual
runtime_status=$?
set -e
[ "$runtime_status" -ne 0 ]
jq -e '.status == "failed" and .rolled_back == true' "$case_state/last-result.json" >/dev/null
assert_file_contains "$case_config/lazy-lock.json" '"commit":"abc"'
assert_file_contains "$case_calls" 'tests/runtime_smoke.lua'
assert_file_contains "$case_calls" 'Lazy! restore'

create_case codecompanion_health_rollback
export FAKE_NVIM_FAIL_CODECOMPANION_HEALTH=1
set +e
"$updater" --manual
codecompanion_status=$?
set -e
[ "$codecompanion_status" -ne 0 ]
jq -e '.status == "failed" and .rolled_back == true' "$case_state/last-result.json" >/dev/null
assert_file_contains "$case_config/lazy-lock.json" '"commit":"abc"'
assert_file_contains "$case_calls" 'checkhealth codecompanion'
assert_file_contains "$case_calls" 'Lazy! restore'

printf 'PASS safe updater dry-run, session/lock exclusion, runtime/parser/health validation, and rollback\n'

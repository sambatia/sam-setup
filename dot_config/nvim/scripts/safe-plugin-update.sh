#!/bin/sh

set -eu
umask 077

usage() {
  printf 'Usage: %s [--automatic|--manual] [--dry-run]\n' "$0" >&2
}

mode=automatic
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --automatic) mode=automatic ;;
    --manual) mode=manual ;;
    --dry-run) dry_run=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
  shift
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
default_config_dir=$(dirname "$script_dir")
config_dir=${NVIM_SAFE_UPDATE_CONFIG_DIR:-$default_config_dir}
config_dir=$(CDPATH='' cd -- "$config_dir" && pwd -P)
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
state_dir=${NVIM_SAFE_UPDATE_STATE_DIR:-"$state_home/nvim/safe-plugin-updates"}
nvim_bin=${NVIM_SAFE_UPDATE_NVIM:-nvim}
interval=${NVIM_SAFE_UPDATE_INTERVAL:-604800}

lockfile="$config_dir/lazy-lock.json"
lock_dir="$state_dir/update.lock"
log_dir="$state_dir/logs"
snapshot_dir="$state_dir/snapshots"
result_file="$state_dir/last-result.json"
last_attempt_file="$state_dir/last-attempt"
last_success_file="$state_dir/last-success"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
now=$(date +%s)
log_file="$log_dir/$run_id.log"
snapshot="$snapshot_dir/lazy-lock.$run_id.json"

find_baseline_backup() {
  if [ -n "${NVIM_SAFE_UPDATE_BASELINE_BACKUP:-}" ]; then
    [ -d "$NVIM_SAFE_UPDATE_BASELINE_BACKUP" ] || return 1
    [ -f "$NVIM_SAFE_UPDATE_BASELINE_BACKUP/lazy-lock.json" ] || return 1
    [ -f "$NVIM_SAFE_UPDATE_BASELINE_BACKUP/init.lua" ] || return 1
    [ -d "$NVIM_SAFE_UPDATE_BASELINE_BACKUP/lua" ] || return 1
    printf '%s\n' "$NVIM_SAFE_UPDATE_BASELINE_BACKUP"
    return 0
  fi

  for candidate in "$HOME"/.config/nvim.backup.*; do
    if
      [ -d "$candidate" ] &&
        [ -f "$candidate/lazy-lock.json" ] &&
        [ -f "$candidate/init.lua" ] &&
        [ -d "$candidate/lua" ]
    then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

write_number() {
  destination=$1
  value=$2
  temporary="$destination.$$.tmp"
  printf '%s\n' "$value" > "$temporary"
  mv "$temporary" "$destination"
}

write_result() {
  status=$1
  rolled_back=$2
  message=$3
  finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  temporary="$result_file.$$.tmp"
  jq -n \
    --arg id "$run_id" \
    --arg status "$status" \
    --arg mode "$mode" \
    --arg started_at "$started_at" \
    --arg finished_at "$finished_at" \
    --arg message "$message" \
    --arg log "$log_file" \
    --arg snapshot "$snapshot" \
    --argjson rolled_back "$rolled_back" \
    '{
      id: $id,
      status: $status,
      mode: $mode,
      started_at: $started_at,
      finished_at: $finished_at,
      rolled_back: $rolled_back,
      message: $message,
      log: $log,
      snapshot: $snapshot
    }' > "$temporary"
  mv "$temporary" "$result_file"
}

initialize_result_state() {
  mkdir -p "$log_dir" "$snapshot_dir"
  : > "$log_file"
}

fail_preflight() {
  message=$1
  printf 'PRECHECK FAILED: %s\n' "$message" >&2
  if [ "$dry_run" -eq 0 ]; then
    initialize_result_state
    printf 'PRECHECK FAILED: %s\n' "$message" >> "$log_file"
    write_result failed false "$message"
  fi
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  printf 'PRECHECK FAILED: jq is unavailable\n' >&2
  exit 1
fi
case "$interval" in
  *[!0-9]* | "") fail_preflight "The update interval must be a non-negative integer" ;;
esac
command -v "$nvim_bin" >/dev/null 2>&1 || fail_preflight "Neovim executable is unavailable"
command -v git >/dev/null 2>&1 || fail_preflight "Git executable is unavailable"
command -v pgrep >/dev/null 2>&1 || fail_preflight "pgrep executable is unavailable"
[ -f "$lockfile" ] || fail_preflight "lazy-lock.json is missing"
jq -e 'type == "object"' "$lockfile" >/dev/null 2>&1 || fail_preflight "lazy-lock.json is invalid"
baseline_backup=$(find_baseline_backup) || fail_preflight "No verified full configuration backup was found"
git -C "$config_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  fail_preflight "The Neovim configuration is not in a Git worktree"
dirty=$(git -C "$config_dir" status --porcelain -- .)
[ -z "$dirty" ] || fail_preflight "The Neovim configuration subtree has uncommitted changes"

if [ "$mode" = "automatic" ] && [ -f "$last_attempt_file" ]; then
  last_attempt=$(sed -n '1p' "$last_attempt_file")
  case "$last_attempt" in
    *[!0-9]* | "") last_attempt=0 ;;
  esac
  if [ $((now - last_attempt)) -lt "$interval" ]; then
    printf 'Automatic update is not due yet.\n'
    exit 0
  fi
fi

parent_pid=${NVIM_SAFE_UPDATE_PARENT_PID:-}
if [ -n "$parent_pid" ]; then
  case "$parent_pid" in
    *[!0-9]* | "") fail_preflight "The initiating Neovim PID is invalid" ;;
  esac

  parent_waits=0
  while kill -0 "$parent_pid" 2>/dev/null && [ "$parent_waits" -lt 50 ]; do
    sleep 0.1
    parent_waits=$((parent_waits + 1))
  done
  if kill -0 "$parent_pid" 2>/dev/null; then
    printf 'The initiating Neovim process did not exit; the update was not started.\n' >&2
    exit 75
  fi
fi

if pgrep -q -x -u "$(id -u)" nvim; then
  printf 'Another Neovim session is active; the update was not started.\n' >&2
  exit 75
fi

if [ "$dry_run" -eq 1 ]; then
  printf 'Safe plugin update is eligible.\n'
  printf 'Configuration: %s\n' "$config_dir"
  printf 'Baseline backup: %s\n' "$baseline_backup"
  printf 'State directory: %s\n' "$state_dir"
  exit 0
fi

cleanup_lock() {
  rm -f "$lock_dir/pid" "$lock_dir/started"
  rmdir "$lock_dir" 2>/dev/null || true
}

on_signal() {
  exit 130
}

acquire_lock() {
  if mkdir "$lock_dir" 2>/dev/null; then
    return 0
  fi

  if [ -f "$lock_dir/pid" ]; then
    existing_pid=$(sed -n '1p' "$lock_dir/pid")
    case "$existing_pid" in
      *[!0-9]* | "") return 1 ;;
    esac
    if kill -0 "$existing_pid" 2>/dev/null; then
      return 1
    fi
    rm -f "$lock_dir/pid" "$lock_dir/started"
    rmdir "$lock_dir" 2>/dev/null || return 1
    mkdir "$lock_dir" 2>/dev/null || return 1
    return 0
  fi

  return 1
}

mkdir -p "$state_dir"
if ! acquire_lock; then
  printf 'Another safe plugin update is already running.\n' >&2
  exit 75
fi
initialize_result_state
printf '%s\n' "$$" > "$lock_dir/pid"
printf '%s\n' "$started_at" > "$lock_dir/started"
trap cleanup_lock EXIT
trap on_signal HUP INT TERM

exec >> "$log_file" 2>&1

printf 'Safe plugin update started: %s\n' "$started_at"
printf 'Mode: %s\n' "$mode"
printf 'Configuration: %s\n' "$config_dir"
printf 'Baseline backup: %s\n' "$baseline_backup"
write_number "$last_attempt_file" "$now"

rollback() {
  reason=$1
  printf 'VALIDATION FAILED: %s\n' "$reason"
  rollback_copy="$lockfile.$$.rollback"
  cp -p "$snapshot" "$rollback_copy"
  mv "$rollback_copy" "$lockfile"

  restore_ok=true
  if ! "$nvim_bin" --headless "+Lazy! restore" "+lua require('config.lazy_validation').assert_no_task_errors()" +qa; then
    restore_ok=false
    printf 'Lazy restore failed; the previous lockfile is still in place.\n'
  fi
  if ! NVIM_CONFIG_DIR="$config_dir" "$nvim_bin" --clean -l "$config_dir/scripts/verify-treesitter.lua"; then
    restore_ok=false
    printf 'Post-rollback Treesitter parser realignment failed.\n'
  fi
  if ! "$nvim_bin" --headless "+lua require('config.lazy_validation').assert_valid_spec()" +qa; then
    restore_ok=false
    printf 'Post-rollback startup validation failed.\n'
  fi

  if [ "$restore_ok" = true ]; then
    message="$reason; previous lockfile and plugin revisions restored"
  else
    message="$reason; previous lockfile restored but plugin restore requires manual attention"
  fi
  write_result failed true "$message"
  printf '%s\n' "$message"
  exit 1
}

if ! "$nvim_bin" --headless "+lua require('config.lazy_validation').assert_valid_spec()" +qa; then
  write_result failed false "Pre-update Neovim startup validation failed"
  exit 1
fi

cp -p "$lockfile" "$snapshot"

if ! "$nvim_bin" --headless "+Lazy! update" \
  "+lua require('config.lazy_validation').assert_no_task_errors()" \
  "+lua require('config.lazy_validation').assert_valid_spec()" +qa
then
  rollback "Lazy update failed"
fi
if ! jq -e 'type == "object"' "$lockfile" >/dev/null 2>&1; then
  rollback "Lazy update produced an invalid lockfile"
fi
if ! "$nvim_bin" --headless "+Lazy! sync" \
  "+lua require('config.lazy_validation').assert_no_task_errors()" \
  "+lua require('config.lazy_validation').assert_valid_spec()" +qa
then
  rollback "Lazy sync failed"
fi
if ! NVIM_CONFIG_DIR="$config_dir" "$nvim_bin" --clean -l "$config_dir/scripts/verify-treesitter.lua"; then
  rollback "Required Treesitter parser installation or validation failed"
fi
if ! "$nvim_bin" --headless "+lua require('config.lazy_validation').assert_valid_spec()" +qa; then
  rollback "Post-update Neovim startup validation failed"
fi
if ! NVIM_SPEC_PHASE=all "$nvim_bin" --clean -l "$config_dir/tests/plugin_spec.lua"; then
  rollback "Plugin specification regression tests failed"
fi
if ! "$nvim_bin" --clean -l "$config_dir/tests/update_policy_spec.lua"; then
  rollback "Update policy regression tests failed"
fi
if ! "$nvim_bin" --headless \
  "+lua require('config.lazy_validation').run_runtime_smoke(vim.fn.stdpath('config') .. '/tests/runtime_smoke.lua')" +qa
then
  rollback "Runtime smoke tests failed"
fi
if ! "$nvim_bin" --headless "+checkhealth lazy vim.lsp vim.treesitter" \
  "+lua require('config.health_validation').assert_no_errors()" +qa
then
  rollback "Core health checks reported an error"
fi
if ! "$nvim_bin" --headless \
  "+lua require('lazy').load({ plugins = { 'codecompanion.nvim' } })" \
  "+checkhealth codecompanion" \
  "+lua require('config.health_validation').assert_no_errors()" +qa
then
  rollback "CodeCompanion health checks reported an error"
fi
if ! jq -e 'type == "object"' "$lockfile" >/dev/null 2>&1; then
  rollback "Final lockfile validation failed"
fi

write_number "$last_success_file" "$now"
write_result success false "Plugin update and validation completed successfully"
printf 'Safe plugin update completed successfully.\n'

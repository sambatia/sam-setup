#!/bin/sh

set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
config_root=$(dirname "$script_dir")
xdg_config_home=$(dirname "$config_root")
test_root=$(mktemp -d "${TMPDIR:-/tmp}/lazyvim-production-tests.XXXXXX")

# Invoked by the signal/exit trap below.
# shellcheck disable=SC2329
cleanup() {
  case "$test_root" in
    "${TMPDIR:-/tmp}"/lazyvim-production-tests.*) rm -rf "$test_root" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

export XDG_CONFIG_HOME="$xdg_config_home"
export XDG_DATA_HOME="$test_root/data"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"

run_lua_test() {
  test_file=$1
  nvim --clean --headless -l "$script_dir/$test_file"
}

run_runtime_failure_contract() {
  output_file="$test_root/runtime-failure.log"
  NVIM_CONFIG_DIR="$config_root" \
    NVIM_RUNTIME_SMOKE_FILE="$script_dir/runtime_failure.lua" \
    nvim --clean --headless \
      "+lua package.path = vim.fs.joinpath(vim.env.NVIM_CONFIG_DIR, 'lua', '?.lua') .. ';' .. package.path; require('config.lazy_validation').run_runtime_smoke(vim.env.NVIM_RUNTIME_SMOKE_FILE)" \
      +qa >"$output_file" 2>&1
  result=$?
  if [ "$result" -eq 0 ]; then
    cat "$output_file" >&2
    return 1
  fi
  grep -F 'synthetic runtime smoke failure' "$output_file" >/dev/null
}

selection=${1:-all}
status=0

case "$selection" in
  colorscheme_spec)
    run_lua_test colorscheme_spec.lua || status=$?
    ;;
  keymaps_spec)
    run_lua_test keymaps_spec.lua || status=$?
    ;;
  note_ux_spec)
    run_lua_test note_ux_spec.lua || status=$?
    ;;
  note_capture_spec)
    run_lua_test note_capture_spec.lua || status=$?
    ;;
  plugin_spec)
    run_lua_test plugin_spec.lua || status=$?
    ;;
  update_policy_spec)
    run_lua_test update_policy_spec.lua || status=$?
    ;;
  safe_updates_spec)
    run_lua_test safe_updates_spec.lua || status=$?
    ;;
  lazy_validation_spec)
    run_lua_test lazy_validation_spec.lua || status=$?
    ;;
  docs_spec)
    run_lua_test docs_spec.lua || status=$?
    ;;
  health_validation_spec)
    run_lua_test health_validation_spec.lua || status=$?
    ;;
  updater_integration)
    "$script_dir/updater_integration.sh" || status=$?
    ;;
  runtime_failure_contract)
    run_runtime_failure_contract || status=$?
    ;;
  all)
    run_lua_test keymaps_spec.lua || status=$?
    run_lua_test colorscheme_spec.lua || status=$?
    run_lua_test note_ux_spec.lua || status=$?
    run_lua_test note_capture_spec.lua || status=$?
    run_lua_test plugin_spec.lua || status=$?
    run_lua_test update_policy_spec.lua || status=$?
    run_lua_test safe_updates_spec.lua || status=$?
    run_lua_test lazy_validation_spec.lua || status=$?
    run_lua_test docs_spec.lua || status=$?
    run_lua_test health_validation_spec.lua || status=$?
    run_runtime_failure_contract || status=$?
    "$script_dir/updater_integration.sh" || status=$?
    ;;
  *)
    printf 'Unknown test selection: %s\n' "$selection" >&2
    status=2
    ;;
esac

exit "$status"

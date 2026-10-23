#!/usr/bin/env bats

load lib/source-root

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/zsh-modules.XXXXXX")"
  export MODULE_DIR="${TEST_ROOT}/.zshrc.d"
  export MANIFEST="${MODULE_DIR}/.module-order"
  export LOAD_LOG="${TEST_ROOT}/load.log"
  export MODULE_LOADER="${MODULE_LOADER:-${TS_SOURCE_ROOT}/dot_zshrc.d/dot_module-loader.zsh}"

  mkdir -p "$MODULE_DIR"
  : >"$LOAD_LOG"
}

teardown() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    case "$TEST_ROOT" in
      "${BATS_TEST_TMPDIR}/zsh-modules."*) /bin/rm -rf -- "$TEST_ROOT" ;;
    esac
  fi
}

write_module() {
  local module_name="$1"
  local marker="$2"
  printf 'print -r -- %q >> "$LOAD_LOG"\n' "$marker" >"${MODULE_DIR}/${module_name}"
}

render_production_modules() {
  local source_root="${TS_SOURCE_ROOT}"
  local source_file source_name target_name

  while IFS= read -r source_file; do
    source_name="${source_file##*/}"
    case "$source_name" in
      dot_*) target_name=".${source_name#dot_}" ;;
      private_*) target_name="${source_name#private_}" ;;
      *) target_name="$source_name" ;;
    esac
    cp "$source_file" "${MODULE_DIR}/${target_name}"
  done < <(find "${source_root}/dot_zshrc.d" -maxdepth 1 -type f \
    \( -name '*.zsh' -o -name 'dot_module-order' \) -print | sort)
}

@test "loader sources every listed module in manifest order" {
  write_module first.zsh first
  write_module second.zsh second
  printf '%s\n' first.zsh second.zsh >"$MANIFEST"

  run env LOAD_LOG="$LOAD_LOG" /bin/zsh -fc \
    'source "$1"; terminal_load_zsh_modules "$2" "$3"' \
    zsh "$MODULE_LOADER" "$MODULE_DIR" "$MANIFEST"

  [ "$status" -eq 0 ]
  [ "$(<"$LOAD_LOG")" = $'first\nsecond' ]
}

@test "validation accepts a complete manifest without sourcing modules" {
  write_module listed.zsh should-not-run
  printf '%s\n' listed.zsh >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -eq 0 ]
  [ ! -s "$LOAD_LOG" ]
}

@test "validation rejects a missing manifest" {
  write_module listed.zsh should-not-run

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"manifest unavailable: $MANIFEST"* ]]
  [ ! -s "$LOAD_LOG" ]
}

@test "validation rejects an unsafe module basename" {
  printf '%s\n' '../escape.zsh' >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid module name: ../escape.zsh"* ]]
  [ ! -s "$LOAD_LOG" ]
}

@test "validation rejects a duplicate manifest entry" {
  write_module repeated.zsh should-not-run
  printf '%s\n' repeated.zsh repeated.zsh >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"duplicate module: repeated.zsh"* ]]
  [ ! -s "$LOAD_LOG" ]
}

@test "validation rejects a listed module that is unavailable" {
  printf '%s\n' missing.zsh >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"listed module unavailable: missing.zsh"* ]]
  [ ! -s "$LOAD_LOG" ]
}

@test "validation rejects an unlisted module before sourcing anything" {
  write_module listed.zsh listed
  write_module orphan.zsh orphan
  printf '%s\n' listed.zsh >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"unlisted module: orphan.zsh"* ]]
  [ ! -s "$LOAD_LOG" ]
}

@test "loading reports a silent module failure and stops before later modules" {
  write_module first.zsh first
  printf '%s\n' 'return 1' >"${MODULE_DIR}/failing.zsh"
  write_module last.zsh last
  printf '%s\n' first.zsh failing.zsh last.zsh >"$MANIFEST"

  run env LOAD_LOG="$LOAD_LOG" /bin/zsh -fc \
    'source "$1"; terminal_load_zsh_modules "$2" "$3"' \
    zsh "$MODULE_LOADER" "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"module failed: failing.zsh"* ]]
  [ "$(<"$LOAD_LOG")" = first ]
}

@test "loading a module preserves Zsh binary module search paths" {
  printf '%s\n' \
    'zmodload zsh/regex || return' \
    '[[ stack-safe -regex-match "^stack-safe$" ]] || return' \
    'print -r -- regex-loaded >>"$LOAD_LOG"' \
    >"${MODULE_DIR}/regex.zsh"
  printf '%s\n' regex.zsh >"$MANIFEST"

  run env LOAD_LOG="$LOAD_LOG" /bin/zsh -fc \
    'source "$1"; terminal_load_zsh_modules "$2" "$3"' \
    zsh "$MODULE_LOADER" "$MODULE_DIR" "$MANIFEST"

  [ "$status" -eq 0 ]
  [ "$(<"$LOAD_LOG")" = regex-loaded ]
}

@test "validation rejects a listed directory" {
  mkdir "${MODULE_DIR}/directory.zsh"
  printf '%s\n' directory.zsh >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"listed module unavailable: directory.zsh"* ]]
}

@test "validation rejects a listed symlink" {
  write_module target.zsh target
  ln -s target.zsh "${MODULE_DIR}/linked.zsh"
  printf '%s\n' linked.zsh target.zsh >"$MANIFEST"

  run /bin/zsh "$MODULE_LOADER" --validate "$MODULE_DIR" "$MANIFEST"

  [ "$status" -ne 0 ]
  [[ "$output" == *"listed module unavailable: linked.zsh"* ]]
}

@test "production manifest covers every managed target module" {
  render_production_modules

  run /bin/zsh "${MODULE_DIR}/.module-loader.zsh" --validate \
    "$MODULE_DIR" "${MODULE_DIR}/.module-order"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "production Tailscale completion hook is side-effect-free at startup" {
  local source_root="${TS_SOURCE_ROOT}"
  local source_hook="${source_root}/dot_zshrc.d/tailscale-completions.zsh"
  local fixture_hook="${TEST_ROOT}/tailscale-completions.zsh"
  local fake_tailscale="${TEST_ROOT}/Tailscale"
  local completion_dir="${TEST_ROOT}/custom/completions"
  local call_log="${TEST_ROOT}/tailscale-calls.log"

  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\\n" "$*" >>"$TAILSCALE_CALL_LOG"' \
    'printf "%s\\n" "#compdef tailscale Tailscale"' \
    >"$fake_tailscale"
  chmod +x "$fake_tailscale"
  awk -v replacement="$fake_tailscale" \
    '{ gsub("/Applications/Tailscale.app/Contents/MacOS/Tailscale", replacement); print }' \
    "$source_hook" >"$fixture_hook"

  run env ZSH_CUSTOM="${TEST_ROOT}/custom" TAILSCALE_CALL_LOG="$call_log" \
    /bin/zsh -fc 'source "$1"' zsh "$fixture_hook"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$call_log" ]
  [ ! -e "${completion_dir}/_tailscale" ]
}

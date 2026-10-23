#!/usr/bin/env bats

load lib/source-root
load lib/pty

setup() {
  TS_SOURCE_ROOT="$(terminal_setup_source_root)" ||
    TS_SOURCE_ROOT="${TS_SOURCE_ROOT}"
  export TS_SOURCE_ROOT
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/zsh-optional-plugins.XXXXXX")"
  export PLUGIN_ROOT="$TEST_ROOT"
  export PLUGIN="$TEST_ROOT/demo.plugin.zsh"
  export LOADER="${OPTIONAL_PLUGIN_LOADER:-${TS_SOURCE_ROOT}/dot_zshrc.d/dot_optional-plugin-loader.zsh}"
  export PRODUCTION_ZSHRC="${PRODUCTION_ZSHRC:-${TS_SOURCE_ROOT}/dot_zshrc}"
  export COMPLETION_PATHS="${COMPLETION_PATHS:-${TS_SOURCE_ROOT}/dot_zshrc.d/completion-paths.zsh}"
  export FZF_MODULE="${FZF_MODULE:-${TS_SOURCE_ROOT}/dot_zshrc.d/fzf.zsh}"
}

teardown() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    case "$TEST_ROOT" in
      "${BATS_TEST_TMPDIR}/zsh-optional-plugins."*) /bin/rm -rf -- "$TEST_ROOT" ;;
    esac
  fi
}

write_zoxide_stub() {
  export ZOXIDE_INIT_LOG="$TEST_ROOT/zoxide-init.log"
  export ZOXIDE_STUB="$TEST_ROOT/zoxide-stub.zsh"
  : >"$ZOXIDE_INIT_LOG"
  printf '%s\n' \
    'zoxide() {' \
    '  print -r -- "$*" >>"$ZOXIDE_INIT_LOG"' \
    '  [[ "$1 $2" == "init zsh" ]] || return 64' \
    '  if [[ "$*" == "init zsh --cmd cd" ]]; then' \
    '    print -r -- "cd() { :; }"' \
    '    print -r -- "cdi() { :; }"' \
    '  else' \
    '    print -r -- "z() { :; }"' \
    '    print -r -- "zi() { :; }"' \
    '  fi' \
    '  print -r -- "__zoxide_z() { :; }"' \
    '}' \
    >"$ZOXIDE_STUB"
}

@test "healthy plugin passes an isolated preflight" {
  printf '%s\n' 'typeset -g DEMO_PLUGIN_LOADED=1' >"$PLUGIN"

  run /bin/zsh "$LOADER" --check demo "$PLUGIN"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "healthy plugin loads into the parent and records its state" {
  printf '%s\n' 'typeset -g DEMO_PLUGIN_LOADED=1' >"$PLUGIN"

  run /bin/zsh -fc '
    source "$1"
    terminal_source_optional_zsh_plugin demo "$2"
    print -r -- "loaded=${DEMO_PLUGIN_LOADED:-0}"
    print -r -- "healthy=${(j:,:)TERMINAL_ZSH_PLUGINS_LOADED}"
    print -r -- "skipped=${(j:,:)TERMINAL_ZSH_PLUGINS_SKIPPED}"
  ' zsh "$LOADER" "$PLUGIN"

  [ "$status" -eq 0 ]
  [[ "$output" == *"loaded=1"* ]]
  [[ "$output" == *"healthy=demo"* ]]
  [[ "$output" == *"skipped="* ]]
}

@test "missing plugin is rejected without breaking the parent shell" {
  run /bin/zsh -fc '
    source "$1"
    terminal_source_optional_zsh_plugin demo "$2"
    print -r -- parent-alive
  ' zsh "$LOADER" "$PLUGIN"

  [ "$status" -eq 0 ]
  [[ "$output" == *"zsh-plugin-loader: optional plugin skipped: demo (unavailable)"* ]]
  [[ "$output" == *"parent-alive"* ]]
}

@test "valid package-manager symlink resolves while a broken symlink is rejected" {
  printf '%s\n' 'typeset -g DEMO_PLUGIN_LOADED=1' >"$TEST_ROOT/real.plugin.zsh"
  ln -s "$TEST_ROOT/real.plugin.zsh" "$PLUGIN"

  run /bin/zsh "$LOADER" --check demo "$PLUGIN"

  [ "$status" -eq 0 ]
  [ -z "$output" ]

  /bin/rm -- "$TEST_ROOT/real.plugin.zsh"
  run /bin/zsh "$LOADER" --check demo "$PLUGIN"

  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "unsafe plugin name is rejected before execution" {
  printf '%s\n' 'typeset -g DEMO_PLUGIN_LOADED=1' >"$PLUGIN"

  run /bin/zsh "$LOADER" --check '../demo' "$PLUGIN"

  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "missing delayed autoload dependency is rejected before parent mutation" {
  printf '%s\n' \
    'typeset -g PARENT_MUTATED=1' \
    'fpath=( "$PLUGIN_ROOT/missing-functions" $fpath )' \
    'autoload -Uz delayed-demo' \
    >"$PLUGIN"

  run env PLUGIN_ROOT="$PLUGIN_ROOT" /bin/zsh -fc '
    source "$1"
    terminal_source_optional_zsh_plugin demo "$2"
    print -r -- "mutated=${PARENT_MUTATED:-0}"
    print -r -- "skipped=${(j:,:)TERMINAL_ZSH_PLUGINS_SKIPPED}"
  ' zsh "$LOADER" "$PLUGIN"

  [ "$status" -eq 0 ]
  [[ "$output" == *"optional plugin skipped: demo (preflight failed)"* ]]
  [[ "$output" == *"mutated=0"* ]]
  [[ "$output" == *"skipped=demo"* ]]
}

@test "interactive-only plugin initialization is exercised by preflight" {
  printf '%s\n' \
    '[[ -o interactive ]] || return 0' \
    'fpath=( "$PLUGIN_ROOT/missing-interactive-functions" $fpath )' \
    'autoload -Uz interactive-delayed-demo' \
    >"$PLUGIN"

  run env PLUGIN_ROOT="$PLUGIN_ROOT" /bin/zsh "$LOADER" --check demo "$PLUGIN"

  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "available delayed autoload dependency passes preflight" {
  mkdir "$TEST_ROOT/functions"
  printf '%s\n' 'delayed-demo() { :; }' >"$TEST_ROOT/functions/delayed-demo"
  printf '%s\n' \
    'fpath=( "$PLUGIN_ROOT/functions" $fpath )' \
    'autoload -Uz delayed-demo' \
    >"$PLUGIN"

  run env PLUGIN_ROOT="$PLUGIN_ROOT" /bin/zsh "$LOADER" --check demo "$PLUGIN"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "syntax error and nonzero source are isolated from the parent" {
  printf '%s\n' 'if then' >"$PLUGIN"

  run /bin/zsh -fc '
    source "$1"
    terminal_source_optional_zsh_plugin syntax-demo "$2"
    print -r -- syntax-parent-alive
  ' zsh "$LOADER" "$PLUGIN"

  [ "$status" -eq 0 ]
  [[ "$output" == *"optional plugin skipped: syntax-demo (preflight failed)"* ]]
  [[ "$output" == *"syntax-parent-alive"* ]]

  printf '%s\n' 'typeset -g SHOULD_NOT_REACH_PARENT=1' 'return 9' >"$PLUGIN"

  run /bin/zsh -fc '
    source "$1"
    terminal_source_optional_zsh_plugin status-demo "$2"
    print -r -- "mutated=${SHOULD_NOT_REACH_PARENT:-0}"
  ' zsh "$LOADER" "$PLUGIN"

  [ "$status" -eq 0 ]
  [[ "$output" == *"optional plugin skipped: status-demo (preflight failed)"* ]]
  [[ "$output" == *"mutated=0"* ]]
}

@test "raw plugin output is suppressed during failed preflight" {
  printf '%s\n' \
    'print -r -- raw-standard-output' \
    'print -u2 -r -- raw-standard-error' \
    'return 1' \
    >"$PLUGIN"

  run /bin/zsh -fc '
    source "$1"
    terminal_source_optional_zsh_plugin quiet-demo "$2"
  ' zsh "$LOADER" "$PLUGIN"

  [ "$status" -eq 0 ]
  [[ "$output" == *"optional plugin skipped: quiet-demo (preflight failed)"* ]]
  [[ "$output" != *"raw-standard-output"* ]]
  [[ "$output" != *"raw-standard-error"* ]]
}

@test "hung plugin times out and its process group is terminated" {
  export PLUGIN_CHILD_PID="$TEST_ROOT/plugin-child.pid"
  printf '%s\n' \
    'sleep 30 &' \
    'print -r -- "$!" >"$PLUGIN_CHILD_PID"' \
    'wait' \
    >"$PLUGIN"

  started="$(date +%s)"
  run env PLUGIN_CHILD_PID="$PLUGIN_CHILD_PID" /bin/zsh "$LOADER" --check demo "$PLUGIN"
  elapsed=$(( $(date +%s) - started ))

  [ "$status" -eq 124 ]
  [ "$elapsed" -lt 5 ]
  [ -z "$output" ]
  [ -s "$PLUGIN_CHILD_PID" ]
  child_pid="$(<"$PLUGIN_CHILD_PID")"
  terminal_setup_wait_for_reap "$child_pid"
  ! kill -0 "$child_pid" 2>/dev/null
}

@test "interactive preflight exits cleanly after a plugin starts a background worker" {
  export PLUGIN_CHILD_PID="$TEST_ROOT/background-plugin-child.pid"
  export PREFLIGHT_STATUS_FILE="$TEST_ROOT/preflight.status"
  export PREFLIGHT_WRAPPER="$TEST_ROOT/run-preflight"
  printf '%s\n' \
    'sleep 30 &' \
    'print -r -- "$!" >"$PLUGIN_CHILD_PID"' \
    >"$PLUGIN"
  printf '%s\n' \
    '#!/bin/sh' \
    '/bin/zsh -df "$LOADER" --check demo "$PLUGIN"' \
    'printf "%s\n" "$?" >"$PREFLIGHT_STATUS_FILE"' \
    >"$PREFLIGHT_WRAPPER"
  chmod +x "$PREFLIGHT_WRAPPER"

  terminal_setup_run_in_pty "$PREFLIGHT_WRAPPER"

  [ "$status" -eq 0 ]
  [ -s "$PREFLIGHT_STATUS_FILE" ]
  [ "$(<"$PREFLIGHT_STATUS_FILE")" -eq 0 ]
  [ -s "$PLUGIN_CHILD_PID" ]
  child_pid="$(<"$PLUGIN_CHILD_PID")"
  terminal_setup_wait_for_reap "$child_pid"
  ! kill -0 "$child_pid" 2>/dev/null
}

@test "one failed plugin does not prevent a later healthy plugin" {
  bad_plugin="$TEST_ROOT/bad.plugin.zsh"
  good_plugin="$TEST_ROOT/good.plugin.zsh"
  printf '%s\n' 'return 1' >"$bad_plugin"
  printf '%s\n' 'typeset -g GOOD_PLUGIN_LOADED=1' >"$good_plugin"

  run /bin/zsh -fc '
    source "$1"
    terminal_source_optional_zsh_plugin bad "$2"
    terminal_source_optional_zsh_plugin good "$3"
    print -r -- "good=${GOOD_PLUGIN_LOADED:-0}"
    print -r -- "loaded=${(j:,:)TERMINAL_ZSH_PLUGINS_LOADED}"
    print -r -- "skipped=${(j:,:)TERMINAL_ZSH_PLUGINS_SKIPPED}"
  ' zsh "$LOADER" "$bad_plugin" "$good_plugin"

  [ "$status" -eq 0 ]
  [[ "$output" == *"good=1"* ]]
  [[ "$output" == *"loaded=good"* ]]
  [[ "$output" == *"skipped=bad"* ]]
}

@test "production zshrc uses guarded upstream-compatible plugin order" {
  completion_paths_line="$(grep -n 'source.*completion-paths\.zsh' "$PRODUCTION_ZSHRC" | cut -d: -f1)"
  autocomplete_line="$(grep -n 'terminal_source_optional_zsh_plugin zsh-autocomplete' "$PRODUCTION_ZSHRC" | cut -d: -f1)"
  omz_line="$(grep -n 'source \"\$ZSH/oh-my-zsh.sh\"' "$PRODUCTION_ZSHRC" | cut -d: -f1)"
  autosuggestions_line="$(grep -n 'terminal_source_optional_zsh_plugin zsh-autosuggestions' "$PRODUCTION_ZSHRC" | cut -d: -f1)"
  additions_line="$(grep -n 'source.*terminal_setup/additions\.zsh' "$PRODUCTION_ZSHRC" | cut -d: -f1)"
  mise_line="$(grep -n 'eval.*mise activate zsh' "$PRODUCTION_ZSHRC" | tail -1 | cut -d: -f1)"
  syntax_highlighting_line="$(grep -n 'terminal_source_optional_zsh_plugin zsh-syntax-highlighting' "$PRODUCTION_ZSHRC" | cut -d: -f1)"

  [ -n "$completion_paths_line" ]
  [ -n "$autocomplete_line" ]
  [ -n "$omz_line" ]
  [ -n "$autosuggestions_line" ]
  [ -n "$additions_line" ]
  [ -n "$mise_line" ]
  [ -n "$syntax_highlighting_line" ]
  [ "$completion_paths_line" -lt "$autocomplete_line" ]
  [ "$autocomplete_line" -lt "$omz_line" ]
  [ "$autosuggestions_line" -gt "$omz_line" ]
  [ "$syntax_highlighting_line" -gt "$additions_line" ]
  [ "$syntax_highlighting_line" -gt "$mise_line" ]
  ! grep -Fq 'source "/opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"' "$PRODUCTION_ZSHRC"
}

@test "completion path helper prepends Homebrew completions once before compinit" {
  completion_root="$TEST_ROOT/homebrew/share/zsh-completions"
  mkdir -p "$completion_root"
  printf '%s\n' '#compdef stack-demo' '_stack_demo() { _arguments }' >"$completion_root/_stack-demo"

  run env HOMEBREW_PREFIX="$TEST_ROOT/homebrew" /bin/zsh -fc '
    compinit_dir=""
    for completion_dir in "${fpath[@]}"; do
      if [[ -r "$completion_dir/compinit" ]]; then
        compinit_dir="$completion_dir"
        break
      fi
    done
    [[ -n "$compinit_dir" ]] || exit 1
    fpath=("$3" /fixture/original "$compinit_dir")
    source "$1"
    source "$1"
    autoload -Uz compinit
    compinit -D -d "$2"
    count=${#${(M)fpath:#"$HOMEBREW_PREFIX/share/zsh-completions"}}
    stale_count=${#${(M)fpath:#"$3"}}
    print -r -- "first=${fpath[1]} count=$count stale=$stale_count function=$(whence -w _stack-demo)"
  ' zsh "$COMPLETION_PATHS" "$TEST_ROOT/zcompdump" "$TEST_ROOT/removed-completion-dir"

  [ "$status" -eq 0 ]
  [[ "$output" == *"first=$completion_root count=1 stale=0 function=_stack-demo: function"* ]]
}

@test "completion cache guard removes a malformed dump before compinit reads it" {
  dump="$TEST_ROOT/zcompdump"
  printf '%s\n' '' '#omz revision: fixture' '#omz fpath: /fixture' >"$dump"
  printf '%s\n' 'compiled fixture' >"${dump}.zwc"

  run env ZSH_COMPDUMP="$dump" /bin/zsh -fc '
    source "$1"
    terminal_prepare_completion_cache 0.2 || exit $?
    print -r -- "dump_present=$([[ -e $ZSH_COMPDUMP ]] && print 1 || print 0)"
    print -r -- "zwc_present=$([[ -e ${ZSH_COMPDUMP}.zwc ]] && print 1 || print 0)"
    terminal_finish_completion_cache
  ' zsh "$COMPLETION_PATHS"

  [ "$status" -eq 0 ]
  [[ "$output" == *"dump_present=0"* ]]
  [[ "$output" == *"zwc_present=0"* ]]
}

@test "completion cache guard preserves a valid dump" {
  dump="$TEST_ROOT/zcompdump"
  printf '#files: 7\tversion: %s\ntypeset -g FIXTURE_COMPLETION_DUMP=1\n' \
    "$(/bin/zsh -fc 'print -r -- "$ZSH_VERSION"')" >"$dump"
  before="$(shasum -a 256 "$dump" | awk '{print $1}')"

  run env ZSH_COMPDUMP="$dump" EXPECTED_DIGEST="$before" /bin/zsh -fc '
    source "$1"
    terminal_prepare_completion_cache 0.2 || exit $?
    actual_digest="${$(shasum -a 256 "$ZSH_COMPDUMP")%% *}"
    print -r -- "preserved=$([[ $actual_digest == $EXPECTED_DIGEST ]] && print yes || print no)"
    terminal_finish_completion_cache
  ' zsh "$COMPLETION_PATHS"

  [ "$status" -eq 0 ]
  [[ "$output" == *"preserved=yes"* ]]
}

@test "completion cache guard uses an uncached fallback when another shell holds the lock" {
  dump="$TEST_ROOT/zcompdump"
  ready="$TEST_ROOT/lock.ready"

  env ZSH_COMPDUMP="$dump" /bin/zsh -fc '
    source "$1"
    terminal_prepare_completion_cache 1 || exit $?
    print -r -- ready >"$2"
    sleep 1
    terminal_finish_completion_cache
  ' zsh "$COMPLETION_PATHS" "$ready" &
  holder_pid=$!

  attempts=0
  while [[ ! -s "$ready" && "$attempts" -lt 100 ]]; do
    sleep 0.02
    attempts=$((attempts + 1))
  done
  [ -s "$ready" ]

  run env TMPDIR="$TEST_ROOT" ZSH_COMPDUMP="$dump" /bin/zsh -fc '
    source "$1"
    terminal_prepare_completion_cache 0.05 || exit $?
    fallback_dump="$ZSH_COMPDUMP"
    print -r -- "isolated=$([[ $fallback_dump != $2 ]] && print yes || print no) fallback=${TERMINAL_COMPINIT_CACHE_FALLBACK:-0}"
    terminal_finish_completion_cache
    print -r -- "temporary_removed=$([[ ! -e $fallback_dump ]] && print yes || print no)"
    print -r -- "restored=$ZSH_COMPDUMP"
  ' zsh "$COMPLETION_PATHS" "$dump"
  wait "$holder_pid"

  [ "$status" -eq 0 ]
  [[ "$output" == *"isolated=yes fallback=1"* ]]
  [[ "$output" == *"temporary_removed=yes"* ]]
  [[ "$output" == *"restored=$dump"* ]]
}

@test "completion cache guard invalidates an OMZ dump when an fpath directory is newer than the dump" {
  dump="$TEST_ROOT/zcompdump-stale"
  comp_dir="$TEST_ROOT/comp-dir"
  mkdir -p "$comp_dir"
  zsh_ver="$(/bin/zsh -fc 'print -r -- "$ZSH_VERSION"')"
  printf '#files: 1\tversion: %s\n#omz fpath: %s\n' "$zsh_ver" "$comp_dir" >"$dump"
  printf 'compiled\n' >"${dump}.zwc"
  touch -t 202501010000 "$dump" "${dump}.zwc"
  touch "$comp_dir"

  run env ZSH_COMPDUMP="$dump" COMP_DIR="$comp_dir" /bin/zsh -fc '
    source "$1"
    fpath=("$COMP_DIR")
    terminal_prepare_completion_cache 0.2 || exit $?
    print -r -- "dump_present=$([[ -e $ZSH_COMPDUMP ]] && print 1 || print 0)"
    print -r -- "zwc_present=$([[ -e ${ZSH_COMPDUMP}.zwc ]] && print 1 || print 0)"
    terminal_finish_completion_cache
  ' zsh "$COMPLETION_PATHS"

  [ "$status" -eq 0 ]
  [[ "$output" == *"dump_present=0"* ]]
  [[ "$output" == *"zwc_present=0"* ]]
}

@test "completion cache guard allows concurrent shared locks when the OMZ dump and zwc are fresh" {
  dump="$TEST_ROOT/zcompdump-shared"
  comp_dir="$TEST_ROOT/comp-dir-shared"
  ready="$TEST_ROOT/shared.ready"
  mkdir -p "$comp_dir"
  touch -t 202501010000 "$comp_dir"
  zsh_ver="$(/bin/zsh -fc 'print -r -- "$ZSH_VERSION"')"
  printf '#files: 1\tversion: %s\n#omz fpath: %s\n' "$zsh_ver" "$comp_dir" >"$dump"
  printf 'compiled\n' >"${dump}.zwc"

  env ZSH_COMPDUMP="$dump" COMP_DIR="$comp_dir" /bin/zsh -fc '
    source "$1"
    fpath=("$COMP_DIR")
    terminal_prepare_completion_cache 1 || exit $?
    print -r -- ready >"$2"
    sleep 0.5
    terminal_finish_completion_cache
  ' zsh "$COMPLETION_PATHS" "$ready" &
  holder_pid=$!

  attempts=0
  while [[ ! -s "$ready" && "$attempts" -lt 100 ]]; do
    sleep 0.02
    attempts=$((attempts + 1))
  done
  [ -s "$ready" ]

  run env TMPDIR="$TEST_ROOT" ZSH_COMPDUMP="$dump" COMP_DIR="$comp_dir" /bin/zsh -fc '
    source "$1"
    fpath=("$COMP_DIR")
    terminal_prepare_completion_cache 0.05 || exit $?
    print -r -- "shared=$([[ $ZSH_COMPDUMP == $2 ]] && print yes || print no) fallback=${TERMINAL_COMPINIT_CACHE_FALLBACK:-0}"
    terminal_finish_completion_cache
  ' zsh "$COMPLETION_PATHS" "$dump"
  wait "$holder_pid"

  [ "$status" -eq 0 ]
  [[ "$output" == *"shared=yes fallback=0"* ]]
}


@test "fzf integration ignores an inherited marker and remains idempotent in one shell" {
  export FZF_TEST_HOME="$TEST_ROOT/fzf-home"
  export FZF_TEST_RUNNER="$TEST_ROOT/run-fzf-integration"
  mkdir -p "$FZF_TEST_HOME"
  printf '%s\n' \
    '(( FZF_TEST_SOURCES++ ))' \
    'fzf-file-widget() { :; }' \
    'fzf-cd-widget() { :; }' \
    'fzf-history-widget() { :; }' \
    'zle -N fzf-file-widget' \
    'zle -N fzf-cd-widget' \
    'zle -N fzf-history-widget' \
    '[[ "${FZF_CTRL_T_COMMAND-x}" != "" ]] && bindkey -M emacs "^T" fzf-file-widget' \
    '[[ "${FZF_ALT_C_COMMAND-x}" != "" ]] && bindkey -M emacs "^[c" fzf-cd-widget' \
    '[[ "${FZF_CTRL_R_COMMAND-x}" != "" ]] && bindkey -M emacs "^R" fzf-history-widget' \
    >"$FZF_TEST_HOME/.fzf.zsh"
  printf '%s\n' \
    '#!/bin/zsh -dfi' \
    'bindkey -e' \
    'bindkey -M emacs "^R" history-incremental-search-backward' \
    'source "$FZF_MODULE"' \
    'source "$FZF_MODULE"' \
    'print -r -- "sources=$FZF_TEST_SOURCES"' \
    'print -r -- "ctrl_t=$(bindkey -M emacs "^T")"' \
    'print -r -- "alt_c=$(bindkey -M emacs "^[c")"' \
    'print -r -- "ctrl_r=$(bindkey -M emacs "^R")"' \
    'print -r -- "marker_type=${(t)FASTOOZ_FZF_LOADED}"' \
    >"$FZF_TEST_RUNNER"
  chmod +x "$FZF_TEST_RUNNER"

  terminal_setup_run_in_pty env HOME="$FZF_TEST_HOME" FZF_MODULE="$FZF_MODULE" \
    FASTOOZ_FZF_LOADED=1 "$FZF_TEST_RUNNER"

  [ "$status" -eq 0 ]
  [[ "$output" == *"sources=1"* ]]
  [[ "$output" == *'ctrl_t="^T" fzf-file-widget'* ]]
  [[ "$output" == *'alt_c="^[c" fzf-cd-widget'* ]]
  [[ "$output" == *'ctrl_r="^R" history-incremental-search-backward'* ]]
  [[ "$output" == *"marker_type=scalar"* ]]
  [[ "$output" != *"marker_type=scalar-export"* ]]
}

@test "primary zoxide startup preserves builtin directory commands and initializes once" {
  local zoxide_section="$TEST_ROOT/zoxide-main.zsh"
  local additions="${ADDITIONS:-${TS_SOURCE_ROOT}/dot_config/terminal_setup/private_additions.zsh}"
  write_zoxide_stub
  awk '/^# ── zoxide /{capture=1; next} /^export FASTOOZ_DIR=/{capture=0} capture{print}' \
    "$PRODUCTION_ZSHRC" >"$zoxide_section"

  run env HOME="$TEST_ROOT" PATH=/usr/bin:/bin \
    FASTOOZ_HOMEBREW_SHELLENV_READY=1 ZOXIDE_INIT_LOG="$ZOXIDE_INIT_LOG" \
    /bin/zsh -fc '
      source "$1"
      source "$2"
      for name in cd pushd popd dirs z zi; do
        print -r -- "primary_$name=$(whence -w "$name")"
      done
      print -r -- "primary_calls=$(wc -l <"$ZOXIDE_INIT_LOG" | tr -d " ")"
      print -r -- "primary_args=$(<"$ZOXIDE_INIT_LOG")"
      source "$3"
      source "$3"
      for name in cd pushd popd dirs z zi; do
        print -r -- "final_$name=$(whence -w "$name")"
      done
    ' zsh "$ZOXIDE_STUB" "$zoxide_section" "$additions"

  [ "$status" -eq 0 ]
  [[ "$output" == *"primary_cd=cd: builtin"* ]]
  [[ "$output" == *"primary_pushd=pushd: builtin"* ]]
  [[ "$output" == *"primary_popd=popd: builtin"* ]]
  [[ "$output" == *"primary_dirs=dirs: builtin"* ]]
  [[ "$output" == *"primary_z=z: function"* ]]
  [[ "$output" == *"primary_zi=zi: function"* ]]
  [[ "$output" == *"primary_calls=1"* ]]
  [[ "$output" == *"primary_args=init zsh"* ]]
  [[ "$output" == *"final_cd=cd: builtin"* ]]
  [[ "$output" == *"final_z=z: function"* ]]
  [[ "$output" == *"final_zi=zi: function"* ]]
  [ "$(wc -l <"$ZOXIDE_INIT_LOG" | tr -d ' ')" -eq 1 ]
  [ "$(<"$ZOXIDE_INIT_LOG")" = "init zsh" ]
}

@test "zoxide additions fallback preserves builtin cd and stays idempotent" {
  local additions="${ADDITIONS:-${TS_SOURCE_ROOT}/dot_config/terminal_setup/private_additions.zsh}"
  write_zoxide_stub

  run env HOME="$TEST_ROOT" PATH=/usr/bin:/bin \
    FASTOOZ_HOMEBREW_SHELLENV_READY=1 ZOXIDE_INIT_LOG="$ZOXIDE_INIT_LOG" \
    /bin/zsh -fc '
      source "$1"
      source "$2"
      source "$2"
      for name in cd pushd popd dirs z zi; do
        print -r -- "$name=$(whence -w "$name")"
      done
    ' zsh "$ZOXIDE_STUB" "$additions"

  [ "$status" -eq 0 ]
  [[ "$output" == *"cd=cd: builtin"* ]]
  [[ "$output" == *"pushd=pushd: builtin"* ]]
  [[ "$output" == *"popd=popd: builtin"* ]]
  [[ "$output" == *"dirs=dirs: builtin"* ]]
  [[ "$output" == *"z=z: function"* ]]
  [[ "$output" == *"zi=zi: function"* ]]
  [ "$(wc -l <"$ZOXIDE_INIT_LOG" | tr -d ' ')" -eq 1 ]
  [ "$(<"$ZOXIDE_INIT_LOG")" = "init zsh" ]
}

# In "${FZF_CTRL_T_OPTS:---preview '... {}'}" the "}" of fzf's {} placeholder
# closed the expansion early and left "'}" as literal text. Every shell then
# appended it again: the module and additions.zsh each added one, and every
# nested shell inherited the result, until fzf rejected the value with
# "$FZF_DEFAULT_OPTS: invalid command line string" (2026-09-30).
@test "fzf preview options are exact after the module and additions, even from a polluted parent" {
  export FZF_TEST_HOME="$TEST_ROOT/fzf-opts-home"
  export FZF_TEST_RUNNER="$TEST_ROOT/run-fzf-opts"
  export ADDITIONS="${ADDITIONS:-${TS_SOURCE_ROOT}/dot_config/terminal_setup/private_additions.zsh}"
  mkdir -p "$FZF_TEST_HOME" "$TEST_ROOT/bin"
  printf '#!/bin/sh\n' >"$TEST_ROOT/bin/bat"
  printf '#!/bin/sh\n' >"$TEST_ROOT/bin/eza"
  chmod +x "$TEST_ROOT/bin/bat" "$TEST_ROOT/bin/eza"
  printf '%s\n' \
    'fzf-file-widget() { :; }' \
    'fzf-cd-widget() { :; }' \
    'zle -N fzf-file-widget' \
    'zle -N fzf-cd-widget' \
    >"$FZF_TEST_HOME/.fzf.zsh"
  printf '%s\n' \
    '#!/bin/zsh -dfi' \
    'source "$FZF_MODULE"' \
    'source "$ADDITIONS"' \
    'print -r -- "ctrl_t=[$FZF_CTRL_T_OPTS]"' \
    'print -r -- "alt_c=[$FZF_ALT_C_OPTS]"' \
    >"$FZF_TEST_RUNNER"
  chmod +x "$FZF_TEST_RUNNER"

  terminal_setup_run_in_pty env HOME="$FZF_TEST_HOME" PATH="$TEST_ROOT/bin:$PATH" \
    FZF_MODULE="$FZF_MODULE" ADDITIONS="$ADDITIONS" STARSHIP_SHELL=zsh \
    FASTOOZ_HOMEBREW_SHELLENV_READY=1 \
    FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :200 {'}'}" \
    FZF_ALT_C_OPTS="--preview 'eza --tree --color=always { | head -200'}" \
    "$FZF_TEST_RUNNER"

  [ "$status" -eq 0 ]
  [[ "$output" == *"ctrl_t=[--preview 'bat -n --color=always --line-range :200 {}']"* ]]
  [[ "$output" == *"alt_c=[--preview 'eza --tree --color=always {} | head -200']"* ]]
}

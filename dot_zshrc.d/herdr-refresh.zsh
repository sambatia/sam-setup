# Safe Herdr-wide Zsh refresh orchestration.

unalias refresh refresh-dry clear-panes clear-panes-dry 2>/dev/null

_herdr_refresh_usage() {
  print -r -- \
    'Usage: refresh [--dry-run] [--clear | --keep-scrollback] [--timeout-ms N]'
  print -r -- \
    '       refresh-dry [--clear | --keep-scrollback] [--timeout-ms N]'
  print -r -- ''
  print -r -- 'Refresh every eligible Herdr Zsh pane, then replace this shell.'
  print -r -- 'Successful refreshes clear by default; use --keep-scrollback for diagnostics.'
  print -r -- 'Shells with pending jobs are preserved; inspect jobs in that pane first.'
  print -r -- '--clear remains available as an explicit spelling of the default.'
  print -r -- '--timeout-ms sets each acknowledgement deadline (default: 15000).'
}

_herdr_refresh_require_executable() {
  local executable="$1"
  if [[ ! -x "$executable" ]]; then
    print -u2 -r -- "refresh: required executable is unavailable: $executable"
    return 127
  fi
}

_herdr_refresh_record_current_failure() {
  local doctor="$1"
  local original_status="$2"

  if [[ -x "$doctor" ]] &&
    command "$doctor" \
      --record \
      --component current-shell \
      --reason current-shell-refresh-failed \
      --exit-status "$original_status" \
      >/dev/null 2>&1; then
    print -u2 -r -- \
      'herdr-refresh: saved a redacted failure record; run refresh-doctor'
  else
    print -u2 -r -- \
      'herdr-refresh: could not save the redacted failure record'
  fi
}

# Inspect the owning shell directly. A command substitution loses Zsh's job
# table, and the external preflight worker cannot inspect it on our behalf.
_herdr_refresh_require_no_jobs() {
  if ! builtin zmodload zsh/parameter 2>/dev/null; then
    print -u2 -r -- 'refresh: cannot inspect jobs; shell was not replaced.'
    return 75
  fi
  if (( ${#jobstates} > 0 )); then
    print -u2 -r -- 'refresh: pending jobs; shell was not replaced:'
    builtin jobs -l >&2
    print -u2 -r -- 'refresh: fg resumes a job and kill %N ends it; then run refresh again.'
    return 75
  fi
}

# Dry runs never stop for jobs, but say when the real command would.
_herdr_refresh_preview_jobs() {
  builtin zmodload zsh/parameter 2>/dev/null || return 0
  (( ${#jobstates} > 0 )) || return 0
  print -r -- "refresh-dry: this shell has ${#jobstates} pending job(s); refresh would stop here and change no panes:"
  builtin jobs -l
}

_herdr_refresh_exec_shell() {
  _herdr_refresh_require_no_jobs || return $?
  exec /bin/zsh -l
}

# Keep this entry point small: source updated definitions in the owning shell,
# then call the newly loaded implementation without recursively calling refresh.
refresh() {
  local refresh_module_path="${ZDOTDIR:-$HOME}/.zshrc.d/herdr-refresh.zsh"
  if [[ ! -f "$refresh_module_path" || ! -r "$refresh_module_path" ]]; then
    print -u2 -r -- 'refresh: refresh module is unavailable; no panes were changed.'
    return 1
  fi
  if ! /bin/zsh -fn "$refresh_module_path" >/dev/null 2>&1; then
    print -u2 -r -- 'refresh: refresh module has invalid syntax; no panes were changed.'
    return 1
  fi
  # Never fall back to a stale implementation if a damaged module omits it.
  unfunction _herdr_refresh_run 2>/dev/null || true
  builtin source "$refresh_module_path" || {
    local reload_status=$?
    print -u2 -r -- 'refresh: could not load refresh module; no panes were changed.'
    return "$reload_status"
  }
  if (( ! $+functions[_herdr_refresh_run] )); then
    print -u2 -r -- 'refresh: refresh implementation is unavailable; no panes were changed.'
    return 1
  fi
  _herdr_refresh_run "$@"
}

_herdr_refresh_run() {
  local controller="$HOME/.local/bin/herdr-refresh-safe-shell-panes"
  local worker="$HOME/.local/bin/zsh-refresh-current"
  local doctor="$HOME/.local/bin/refresh-doctor"
  local dry_run=0
  local clear_requested=1
  local clear_explicit=0
  local keep_scrollback=0
  local timeout_ms=""
  local worker_status
  local -a controller_args worker_args

  while (( $# > 0 )); do
    case "$1" in
      --dry-run)
        dry_run=1
        shift
        ;;
      --clear)
        clear_explicit=1
        shift
        ;;
      --keep-scrollback)
        keep_scrollback=1
        shift
        ;;
      --timeout-ms)
        if (( $# < 2 )); then
          print -u2 -r -- 'refresh: --timeout-ms requires a value'
          return 2
        fi
        timeout_ms="$2"
        if [[ ! "$timeout_ms" =~ ^[0-9]+$ ]] ||
          (( timeout_ms < 100 || timeout_ms > 60000 )); then
          print -u2 -r -- "refresh: invalid timeout: $timeout_ms"
          return 2
        fi
        shift 2
        ;;
      --help|-h)
        _herdr_refresh_usage
        return 0
        ;;
      *)
        print -u2 -r -- "refresh: unknown argument: $1"
        _herdr_refresh_usage >&2
        return 2
        ;;
    esac
  done

  if (( clear_explicit && keep_scrollback )); then
    print -u2 -r -- 'refresh: --clear and --keep-scrollback cannot be combined'
    return 2
  fi
  (( keep_scrollback )) && clear_requested=0

  _herdr_refresh_require_executable "$controller" || return $?
  _herdr_refresh_require_executable "$worker" || return $?

  if (( dry_run )); then
    controller_args=(--dry-run)
    worker_args=(--check)
  else
    controller_args=(--apply --quiet)
    worker_args=()
  fi
  if [[ -n "$timeout_ms" ]]; then
    controller_args+=(--timeout-ms "$timeout_ms")
  fi

  if (( clear_requested )); then
    controller_args+=(--clear)
    if (( ! dry_run )); then
      worker_args+=(--clear)
    fi
  fi

  if [[ -n "${HERDR_PANE_ID:-}" ]]; then
    controller_args+=(--exclude-pane "$HERDR_PANE_ID")
  fi

  if (( dry_run )); then
    _herdr_refresh_preview_jobs
  else
    _herdr_refresh_require_no_jobs || return $?
  fi
  command "$controller" "${controller_args[@]}" || return $?
  if (( ! dry_run )); then
    _herdr_refresh_require_no_jobs || return $?
  fi
  command "$worker" "${worker_args[@]}"
  worker_status=$?
  if (( worker_status != 0 )); then
    if (( ! dry_run )); then
      _herdr_refresh_record_current_failure "$doctor" "$worker_status"
    fi
    return "$worker_status"
  fi
  (( dry_run )) && return 0
  _herdr_refresh_exec_shell
}

refresh-dry() {
  refresh --dry-run "$@"
}

_herdr_clear_panes() {
  local dry_run="$1"
  shift
  local controller="$HOME/.local/bin/herdr-refresh-safe-shell-panes"
  local arg
  local -a controller_args

  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        print -r -- 'Usage: clear-panes'
        print -r -- '       clear-panes-dry'
        return 0
        ;;
      *)
        print -u2 -r -- "clear-panes: unknown argument: $arg"
        return 2
        ;;
    esac
  done

  _herdr_refresh_require_executable "$controller" || return $?

  if (( dry_run )); then
    controller_args=(--dry-run --clear-only)
  else
    controller_args=(--apply --quiet --clear-only)
  fi
  if [[ -n "${HERDR_PANE_ID:-}" ]]; then
    controller_args+=(--exclude-pane "$HERDR_PANE_ID")
  fi

  command "$controller" "${controller_args[@]}" || return $?
  (( dry_run )) && return 0

  command clear || return $?
  printf '\e[3J'
}

clear-panes() {
  _herdr_clear_panes 0 "$@"
}

clear-panes-dry() {
  _herdr_clear_panes 1 "$@"
}

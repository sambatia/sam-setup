# Safe Herdr-wide Zsh refresh orchestration.

unalias refresh refresh-dry clear-panes clear-panes-dry 2>/dev/null

_herdr_refresh_usage() {
  print -r -- \
    'Usage: refresh [OPTIONS]'
  print -r -- \
    '       refresh-dry [OPTIONS]'
  print -r -- ''
  print -r -- 'Refresh every eligible Herdr Zsh pane, then replace this shell.'
  print -r -- 'Successful refreshes clear by default; use --keep-scrollback for diagnostics.'
  print -r -- 'Shells with pending jobs are preserved; inspect jobs in that pane first.'
  print -r -- ''
  print -r -- 'Options:'
  print -r -- '  --dry-run             Preview selection and preflight this shell without mutating.'
  print -r -- '  --clear               Explicit spelling of the default clear-on-success policy.'
  print -r -- '  --keep-scrollback     Preserve prior scrollback instead of clearing.'
  print -r -- '  --current-only        Validate and replace only this shell (skip other panes).'
  print -r -- '  --here                Limit remote refresh to the current Herdr workspace.'
  print -r -- '  --workspace ID        Limit remote refresh to one Herdr workspace.'
  print -r -- '  --session NAME        Select a named Herdr session.'
  print -r -- '  --concurrency N       Max panes refreshed in parallel (1-32, default: 6).'
  print -r -- '  --timeout-ms N        Acknowledgement / preflight timeout in ms (100-60000, default: 15000).'
  print -r -- '  --verbose, -v         Show per-pane controller details.'
  print -r -- '  -h, --help            Show this help.'
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

_herdr_refresh_current_pane_json() {
  [[ "${HERDR_ENV:-}" == "1" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local herdr_bin=""
  local resolver="$HOME/.local/libexec/herdr-refresh-client"
  if command -v herdr >/dev/null 2>&1; then
    command herdr pane current --current 2>/dev/null && return 0
  fi
  if [[ -x "$resolver" ]] &&
    herdr_bin="$(command "$resolver" --read-only --quiet 2>/dev/null)" &&
    [[ -x "$herdr_bin" ]]; then
    command "$herdr_bin" pane current --current 2>/dev/null && return 0
  fi
  return 1
}

_herdr_refresh_live_workspace_id() {
  local pane_json live_ws
  if pane_json="$(_herdr_refresh_current_pane_json)"; then
    live_ws="$(printf '%s' "$pane_json" | command jq -r '.result.pane.workspace_id? // empty' 2>/dev/null)"
    if [[ -n "$live_ws" ]]; then
      print -r -- "$live_ws"
      return 0
    fi
  fi
  if [[ -n "${HERDR_WORKSPACE_ID:-}" ]]; then
    print -r -- "$HERDR_WORKSPACE_ID"
    return 0
  fi
  return 1
}

_herdr_refresh_sync_moved_env() {
  local pane_json pane_id tab_id ws_id
  pane_json="$(_herdr_refresh_current_pane_json)" || return 0
  {
    IFS= read -r pane_id
    IFS= read -r tab_id
    IFS= read -r ws_id
  } <<<"$(printf '%s' "$pane_json" | command jq -r '
    (.result.pane.pane_id? // ""),
    (.result.pane.tab_id? // ""),
    (.result.pane.workspace_id? // "")
  ' 2>/dev/null)"
  [[ -n "$pane_id" ]] && export HERDR_PANE_ID="$pane_id"
  [[ -n "$tab_id" ]] && export HERDR_TAB_ID="$tab_id"
  [[ -n "$ws_id" ]] && export HERDR_WORKSPACE_ID="$ws_id"
  return 0
}

_herdr_refresh_exec_shell() {
  _herdr_refresh_require_no_jobs || return $?
  _herdr_refresh_sync_moved_env
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

_herdr_refresh_validate_workspace() {
  local caller="$1" value="$2"
  if [[ ! "$value" =~ ^[A-Za-z0-9_-]{1,32}$ ]]; then
    print -u2 -r -- "${caller}: invalid workspace ID: $value"
    return 2
  fi
}

_herdr_refresh_validate_session() {
  local caller="$1" value="$2"
  if [[ ! "$value" =~ ^[A-Za-z0-9._-]{1,64}$ ]]; then
    print -u2 -r -- "${caller}: invalid session name: $value"
    return 2
  fi
}

_herdr_refresh_validate_concurrency() {
  local caller="$1" value="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 1 || value > 32 )); then
    print -u2 -r -- "${caller}: invalid concurrency: $value"
    return 2
  fi
}

_herdr_refresh_validate_timeout_ms() {
  local caller="$1" value="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 100 || value > 60000 )); then
    print -u2 -r -- "${caller}: invalid timeout: $value"
    return 2
  fi
}

_herdr_refresh_resolve_scope() {
  local caller="$1" current_only="$2" here_requested="$3" verbose="$4"
  local workspace_id="$5" session_name="$6" concurrency="$7"

  if (( here_requested )) && [[ -n "$workspace_id" ]]; then
    print -u2 -r -- "${caller}: --here and --workspace cannot be combined"
    return 2
  fi
  if (( current_only )) && { (( here_requested || verbose )) || [[ -n "$workspace_id" || -n "$session_name" || -n "$concurrency" ]]; }; then
    print -u2 -r -- "${caller}: --current-only cannot be combined with remote scope options"
    return 2
  fi
  if (( here_requested )); then
    if ! REPLY="$(_herdr_refresh_live_workspace_id)" || [[ ! "$REPLY" =~ ^[A-Za-z0-9_-]{1,32}$ ]]; then
      print -u2 -r -- "${caller}: --here requires an active Herdr workspace (or pass --workspace ID)"
      return 2
    fi
  else
    REPLY="$workspace_id"
  fi
}

_herdr_refresh_run() {
  local controller="$HOME/.local/bin/herdr-refresh-safe-shell-panes"
  local worker="$HOME/.local/bin/zsh-refresh-current"
  local doctor="$HOME/.local/bin/refresh-doctor"
  local dry_run=0
  local clear_requested=1
  local clear_explicit=0
  local keep_scrollback=0
  local current_only=0
  local here_requested=0
  local verbose=0
  local workspace_id=""
  local session_name=""
  local concurrency=""
  local timeout_ms=""
  local worker_status
  local -a controller_args worker_args preflight_args

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
      --current-only|--local)
        current_only=1
        shift
        ;;
      --here)
        here_requested=1
        shift
        ;;
      --workspace=*)
        set -- --workspace "${1#*=}" "${@:2}"
        continue
        ;;
      --workspace)
        (( $# >= 2 )) || { print -u2 -r -- 'refresh: --workspace requires an ID'; return 2; }
        _herdr_refresh_validate_workspace refresh "$2" || return 2
        workspace_id="$2"
        shift 2
        ;;
      --session=*)
        set -- --session "${1#*=}" "${@:2}"
        continue
        ;;
      --session)
        (( $# >= 2 )) || { print -u2 -r -- 'refresh: --session requires a name'; return 2; }
        _herdr_refresh_validate_session refresh "$2" || return 2
        session_name="$2"
        shift 2
        ;;
      --concurrency=*)
        set -- --concurrency "${1#*=}" "${@:2}"
        continue
        ;;
      --concurrency)
        (( $# >= 2 )) || { print -u2 -r -- 'refresh: --concurrency requires a value'; return 2; }
        _herdr_refresh_validate_concurrency refresh "$2" || return 2
        concurrency="$2"
        shift 2
        ;;
      --timeout-ms=*)
        set -- --timeout-ms "${1#*=}" "${@:2}"
        continue
        ;;
      --timeout-ms)
        (( $# >= 2 )) || { print -u2 -r -- 'refresh: --timeout-ms requires a value'; return 2; }
        _herdr_refresh_validate_timeout_ms refresh "$2" || return 2
        timeout_ms="$2"
        shift 2
        ;;
      --verbose|-v)
        verbose=1
        shift
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
  local REPLY=""
  _herdr_refresh_resolve_scope refresh "$current_only" "$here_requested" "$verbose" \
    "$workspace_id" "$session_name" "$concurrency" || return $?
  workspace_id="$REPLY"
  (( keep_scrollback )) && clear_requested=0

  if (( ! current_only )); then
    _herdr_refresh_require_executable "$controller" || return $?
  fi
  _herdr_refresh_require_executable "$worker" || return $?

  if (( dry_run )); then
    controller_args=(--dry-run)
    worker_args=(--check)
  elif (( verbose )); then
    controller_args=(--apply)
    worker_args=()
  else
    controller_args=(--apply --quiet)
    worker_args=()
  fi
  (( verbose )) && controller_args+=(--verbose)
  [[ -n "$workspace_id" ]] && controller_args+=(--workspace "$workspace_id")
  [[ -n "$session_name" ]] && controller_args+=(--session "$session_name")
  [[ -n "$concurrency" ]] && controller_args+=(--concurrency "$concurrency")
  if [[ -n "$timeout_ms" ]]; then
    controller_args+=(--timeout-ms "$timeout_ms")
    worker_args+=(--timeout-ms "$timeout_ms")
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

  if (( ! current_only )); then
    # Validate the current shell startup BEFORE mutating remote panes so a broken
    # ~/.zshrc or module never sprays preflight errors across dozens of panes.
    if (( ! dry_run )); then
      preflight_args=(--check)
      [[ -n "$timeout_ms" ]] && preflight_args+=(--timeout-ms "$timeout_ms")
      command "$worker" "${preflight_args[@]}"
      worker_status=$?
      if (( worker_status != 0 )); then
        _herdr_refresh_record_current_failure "$doctor" "$worker_status"
        return "$worker_status"
      fi
      _herdr_refresh_require_no_jobs || return $?
    fi
    command "$controller" "${controller_args[@]}" || return $?
    if (( ! dry_run )); then
      _herdr_refresh_require_no_jobs || return $?
    fi
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
  local current_only=0
  local here_requested=0
  local verbose=0
  local workspace_id=""
  local session_name=""
  local concurrency=""
  local timeout_ms=""
  local -a controller_args

  while (( $# > 0 )); do
    case "$1" in
      --current-only|--local)
        current_only=1
        shift
        ;;
      --here)
        here_requested=1
        shift
        ;;
      --workspace=*)
        set -- --workspace "${1#*=}" "${@:2}"
        continue
        ;;
      --workspace)
        (( $# >= 2 )) || { print -u2 -r -- 'clear-panes: --workspace requires an ID'; return 2; }
        _herdr_refresh_validate_workspace clear-panes "$2" || return 2
        workspace_id="$2"
        shift 2
        ;;
      --session=*)
        set -- --session "${1#*=}" "${@:2}"
        continue
        ;;
      --session)
        (( $# >= 2 )) || { print -u2 -r -- 'clear-panes: --session requires a name'; return 2; }
        _herdr_refresh_validate_session clear-panes "$2" || return 2
        session_name="$2"
        shift 2
        ;;
      --concurrency=*)
        set -- --concurrency "${1#*=}" "${@:2}"
        continue
        ;;
      --concurrency)
        (( $# >= 2 )) || { print -u2 -r -- 'clear-panes: --concurrency requires a value'; return 2; }
        _herdr_refresh_validate_concurrency clear-panes "$2" || return 2
        concurrency="$2"
        shift 2
        ;;
      --timeout-ms=*)
        set -- --timeout-ms "${1#*=}" "${@:2}"
        continue
        ;;
      --timeout-ms)
        (( $# >= 2 )) || { print -u2 -r -- 'clear-panes: --timeout-ms requires a value'; return 2; }
        _herdr_refresh_validate_timeout_ms clear-panes "$2" || return 2
        timeout_ms="$2"
        shift 2
        ;;
      --verbose|-v)
        verbose=1
        shift
        ;;
      --help|-h)
        print -r -- 'Usage: clear-panes [--here | --workspace ID] [--current-only] [--session NAME] [--timeout-ms N] [--concurrency N] [--verbose]'
        print -r -- '       clear-panes-dry [--here | --workspace ID] [--current-only] [--session NAME] [--timeout-ms N] [--concurrency N] [--verbose]'
        return 0
        ;;
      *)
        print -u2 -r -- "clear-panes: unknown argument: $1"
        return 2
        ;;
    esac
  done

  local REPLY=""
  _herdr_refresh_resolve_scope clear-panes "$current_only" "$here_requested" "$verbose" \
    "$workspace_id" "$session_name" "$concurrency" || return $?
  workspace_id="$REPLY"

  if (( ! current_only )); then
    _herdr_refresh_require_executable "$controller" || return $?

    if (( dry_run )); then
      controller_args=(--dry-run --clear-only)
    elif (( verbose )); then
      controller_args=(--apply --clear-only)
    else
      controller_args=(--apply --quiet --clear-only)
    fi
    (( verbose )) && controller_args+=(--verbose)
    [[ -n "$workspace_id" ]] && controller_args+=(--workspace "$workspace_id")
    [[ -n "$session_name" ]] && controller_args+=(--session "$session_name")
    [[ -n "$concurrency" ]] && controller_args+=(--concurrency "$concurrency")
    [[ -n "$timeout_ms" ]] && controller_args+=(--timeout-ms "$timeout_ms")
    if [[ -n "${HERDR_PANE_ID:-}" ]]; then
      controller_args+=(--exclude-pane "$HERDR_PANE_ID")
    fi

    command "$controller" "${controller_args[@]}" || return $?
  fi
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

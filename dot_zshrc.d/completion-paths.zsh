# Make Homebrew's additional completion definitions visible before compinit.
typeset -gU fpath
_terminal_zsh_completions="${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-completions"
_terminal_valid_fpath=()
for _terminal_completion_dir in "${fpath[@]}"; do
  [[ -d "$_terminal_completion_dir" ]] && _terminal_valid_fpath+=("$_terminal_completion_dir")
done
if [[ -d "$_terminal_zsh_completions" ]]; then
  fpath=("$_terminal_zsh_completions" ${_terminal_valid_fpath:#"$_terminal_zsh_completions"})
else
  fpath=("${_terminal_valid_fpath[@]}")
fi
unset _terminal_zsh_completions _terminal_valid_fpath _terminal_completion_dir

# Oh My Zsh may remove, rebuild, and append metadata to one shared completion
# dump during startup. Serialize that window so simultaneous pane refreshes
# cannot expose a missing or partial header to compinit.
typeset -g TERMINAL_COMPINIT_CACHE_FALLBACK=0
typeset -g _TERMINAL_COMPINIT_CACHE_TARGET=""
typeset -g _TERMINAL_COMPINIT_FALLBACK_DUMP=""
typeset -g _TERMINAL_COMPINIT_LOCK_FD=""

_terminal_completion_dump_valid() {
  emulate -L zsh
  setopt local_options extended_glob no_aliases

  (( $# == 1 )) || return 2
  local dump_file="$1"
  local -a dump_header

  [[ ! -e "$dump_file" && ! -L "$dump_file" ]] && return 0
  [[ -f "$dump_file" && ! -L "$dump_file" && -r "$dump_file" ]] || return 1
  IFS=$' \t' read -rA dump_header <"$dump_file" 2>/dev/null || return 1

  [[ "${dump_header[1]:-}" == '#files:' &&
    "${dump_header[2]:-}" == <-> &&
    "${dump_header[3]:-}" == 'version:' &&
    "${dump_header[4]:-}" == "$ZSH_VERSION" ]]
}

_terminal_completion_dump_fpath_stale() {
  emulate -L zsh
  setopt local_options extended_glob no_aliases

  (( $# == 1 )) || return 2
  local dump_file="$1"
  local omz_fpath_line completion_dir
  local -a recorded_dirs

  [[ -f "$dump_file" && ! -L "$dump_file" && -r "$dump_file" ]] || return 1
  omz_fpath_line="$(command grep '^#omz fpath: ' "$dump_file" 2>/dev/null)" || return 1
  recorded_dirs=(${=omz_fpath_line#\#omz fpath: })

  for completion_dir in "${fpath[@]}"; do
    [[ -d "$completion_dir" ]] || continue
    (( ${recorded_dirs[(Ie)$completion_dir]} )) || return 0
    [[ "$completion_dir" -nt "$dump_file" ]] && return 0
  done

  for completion_dir in "${recorded_dirs[@]}"; do
    [[ -d "$completion_dir" && "$completion_dir" -nt "$dump_file" ]] && return 0
  done
  return 1
}

_terminal_completion_dump_ready_for_shared_read() {
  emulate -L zsh
  setopt local_options extended_glob no_aliases

  (( $# == 1 )) || return 2
  local dump_file="$1"

  [[ -f "$dump_file" && ! -L "$dump_file" && -r "$dump_file" ]] || return 1
  [[ -f "${dump_file}.zwc" && ! -L "${dump_file}.zwc" && -r "${dump_file}.zwc" &&
    ! "$dump_file" -nt "${dump_file}.zwc" ]] || return 1
  _terminal_completion_dump_valid "$dump_file" || return 1
  command grep -q '^#omz fpath: ' "$dump_file" 2>/dev/null || return 1
  ! _terminal_completion_dump_fpath_stale "$dump_file"
}

_terminal_use_isolated_completion_dump() {
  emulate -L zsh
  setopt local_options no_aliases

  local temporary_root="${TMPDIR:-/tmp}"
  local fallback_dump
  fallback_dump="$(command mktemp \
    "${temporary_root%/}/zcompdump.${EUID}.${ZSH_VERSION}.XXXXXX" 2>/dev/null)" ||
    fallback_dump="${_TERMINAL_COMPINIT_CACHE_TARGET}.fallback.${$}.${RANDOM}"

  typeset -g _TERMINAL_COMPINIT_FALLBACK_DUMP="$fallback_dump"
  typeset -g ZSH_COMPDUMP="$fallback_dump"
  typeset -g TERMINAL_COMPINIT_CACHE_FALLBACK=1
}

terminal_prepare_completion_cache() {
  emulate -L zsh
  setopt local_options extended_glob no_aliases

  (( $# <= 1 )) || return 2
  local lock_timeout="${1:-5}"
  [[ "$lock_timeout" == <->(|.<->) ]] || return 2
  [[ -z "$_TERMINAL_COMPINIT_CACHE_TARGET" ]] || return 2

  local short_host lock_file
  if [[ -z "${ZSH_COMPDUMP:-}" ]]; then
    if [[ "$OSTYPE" == darwin* && -x /usr/sbin/scutil ]]; then
      short_host="$(/usr/sbin/scutil --get LocalHostName 2>/dev/null)" ||
        short_host="${HOST/.*/}"
    else
      short_host="${HOST/.*/}"
    fi
    typeset -g ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${short_host}-${ZSH_VERSION}"
  fi

  typeset -g _TERMINAL_COMPINIT_CACHE_TARGET="$ZSH_COMPDUMP"
  typeset -g _TERMINAL_COMPINIT_FALLBACK_DUMP=""
  typeset -g TERMINAL_COMPINIT_CACHE_FALLBACK=0
  lock_file="${ZSH_COMPDUMP}.init-lock"

  if [[ ! -e "$lock_file" && ! -L "$lock_file" ]]; then
    (
      setopt local_options no_clobber
      umask 077
      : >"$lock_file"
    ) 2>/dev/null || true
  fi

  if [[ -f "$lock_file" && ! -L "$lock_file" && -O "$lock_file" && -w "$lock_file" ]] &&
    zmodload -F zsh/system b:zsystem 2>/dev/null; then
    if _terminal_completion_dump_ready_for_shared_read "$ZSH_COMPDUMP" &&
      zsystem flock -r -t "$lock_timeout" -i 0.005 -f _TERMINAL_COMPINIT_LOCK_FD \
        "$lock_file" 2>/dev/null; then
      if _terminal_completion_dump_ready_for_shared_read "$ZSH_COMPDUMP"; then
        return 0
      fi
      zsystem flock -u "$_TERMINAL_COMPINIT_LOCK_FD" 2>/dev/null || true
      typeset -g _TERMINAL_COMPINIT_LOCK_FD=""
    fi

    if zsystem flock -t 0 -f _TERMINAL_COMPINIT_LOCK_FD \
      "$lock_file" 2>/dev/null; then
      if ! _terminal_completion_dump_valid "$ZSH_COMPDUMP" ||
        _terminal_completion_dump_fpath_stale "$ZSH_COMPDUMP"; then
        if ! command rm -f -- \
          "$ZSH_COMPDUMP" "${ZSH_COMPDUMP}.zwc" "${ZSH_COMPDUMP}.zwc.old"; then
          _terminal_use_isolated_completion_dump
        fi
      fi
      return 0
    fi

    if zsystem flock -r -t "$lock_timeout" -i 0.005 -f _TERMINAL_COMPINIT_LOCK_FD \
      "$lock_file" 2>/dev/null; then
      if [[ -f "$ZSH_COMPDUMP" ]] &&
        _terminal_completion_dump_valid "$ZSH_COMPDUMP" &&
        ! _terminal_completion_dump_fpath_stale "$ZSH_COMPDUMP"; then
        return 0
      fi
      zsystem flock -u "$_TERMINAL_COMPINIT_LOCK_FD" 2>/dev/null || true
      typeset -g _TERMINAL_COMPINIT_LOCK_FD=""
      if zsystem flock -t "$lock_timeout" -i 0.005 -f _TERMINAL_COMPINIT_LOCK_FD \
        "$lock_file" 2>/dev/null; then
        if ! _terminal_completion_dump_valid "$ZSH_COMPDUMP" ||
          _terminal_completion_dump_fpath_stale "$ZSH_COMPDUMP"; then
          if ! command rm -f -- \
            "$ZSH_COMPDUMP" "${ZSH_COMPDUMP}.zwc" "${ZSH_COMPDUMP}.zwc.old"; then
            _terminal_use_isolated_completion_dump
          fi
        fi
        return 0
      fi
    fi
  fi

  # An isolated initialization is slower but never touches the contended dump.
  _terminal_use_isolated_completion_dump
  return 0
}

terminal_finish_completion_cache() {
  emulate -L zsh
  setopt local_options no_aliases

  local finish_status=0
  if [[ -n "$_TERMINAL_COMPINIT_LOCK_FD" ]]; then
    zsystem flock -u "$_TERMINAL_COMPINIT_LOCK_FD" 2>/dev/null || finish_status=$?
  fi
  if [[ -n "$_TERMINAL_COMPINIT_FALLBACK_DUMP" ]]; then
    command rm -f -- \
      "$_TERMINAL_COMPINIT_FALLBACK_DUMP" \
      "${_TERMINAL_COMPINIT_FALLBACK_DUMP}.zwc" \
      "${_TERMINAL_COMPINIT_FALLBACK_DUMP}.zwc.old" 2>/dev/null || true
  fi
  if (( TERMINAL_COMPINIT_CACHE_FALLBACK )) &&
    [[ -n "$_TERMINAL_COMPINIT_CACHE_TARGET" ]]; then
    typeset -g ZSH_COMPDUMP="$_TERMINAL_COMPINIT_CACHE_TARGET"
  fi

  typeset -g TERMINAL_COMPINIT_CACHE_FALLBACK=0
  typeset -g _TERMINAL_COMPINIT_CACHE_TARGET=""
  typeset -g _TERMINAL_COMPINIT_FALLBACK_DUMP=""
  typeset -g _TERMINAL_COMPINIT_LOCK_FD=""
  return "$finish_status"
}

# ── Prompt-latency probe ─────────────────────────────────────────────────────
# Added 2026-07-05 — terminal-performance-regression investigation.
# Measures, per prompt: time from command end (precmd fire) to the line editor
# being ready for input (zle-line-init fire). Written to answer one question:
# when the terminal "feels stuck for ~2s after exiting a TUI", was the shell
# actually busy, or was the delay outside the shell (keyboard/BLE, renderer)?
#
# Reading the log (~/.local/state/prompt_latency.log):
#   gap_ms large (>1000) at the moment you felt the stall  -> shell-side; the
#     timestamp identifies when the shell-side delay occurred.
#   gap_ms small (<150) at that moment                     -> the shell was
#     ready; look at keyboard/Bluetooth or terminal rendering instead.
# Logs every gap >300ms, plus ~1-in-50 sample of normal prompts for baseline.
#
# Remove: delete this file and its line in ~/.zshrc's module list, or see the
# rollback section of ~/TERMINAL-PERFORMANCE-REGRESSION-REPORT.md.
zmodload zsh/datetime 2>/dev/null

# Shells opened before command logging was retired can recreate this file until
# they reload. A newly loaded configuration owns the migration cleanup.
typeset _plp_legacy_command_log="${XDG_STATE_HOME:-$HOME/.local/state}/last_cmd.log"
if [[ -f "$_plp_legacy_command_log" && ! -L "$_plp_legacy_command_log" ]]; then
  /bin/rm -f -- "$_plp_legacy_command_log"
fi
unset _plp_legacy_command_log

typeset -g _plp_cmd_end=

_plp_precmd()  { _plp_cmd_end=$EPOCHREALTIME }

_plp_line_init() {
  [[ -n $_plp_cmd_end ]] || return 0
  local now=$EPOCHREALTIME
  local -i gap_ms=$(( (now - _plp_cmd_end) * 1000 ))
  _plp_cmd_end=
  if (( gap_ms > 300 )) || (( RANDOM % 50 == 0 )); then
    local log="${XDG_STATE_HOME:-$HOME/.local/state}/prompt_latency.log"
    local ts log_tmp=''
    strftime -s ts '%Y-%m-%dT%H:%M:%S' $EPOCHSECONDS 2>/dev/null
    (
      umask 077
      mkdir -p "${log:h}" 2>/dev/null || return 0
      [[ ! -L "$log" && ( ! -e "$log" || -f "$log" ) ]] || return 0
      [[ ! -e "$log" ]] || chmod 600 "$log" 2>/dev/null || return 0
      print -r -- "${ts:-?}	gap_ms=${gap_ms}" >> "$log" 2>/dev/null || return 0
      chmod 600 "$log" 2>/dev/null || return 0

      local -i _count
      _count=$(wc -l < "$log" 2>/dev/null || echo 0)
      if (( _count > 2000 )); then
        log_tmp=$(mktemp "${log}.tmp.XXXXXX") || return 0
        tail -500 "$log" > "$log_tmp" 2>/dev/null &&
          chmod 600 "$log_tmp" 2>/dev/null &&
          mv -f "$log_tmp" "$log" 2>/dev/null
        [[ ! -e "$log_tmp" ]] || rm -f -- "$log_tmp"
      fi
    )
  fi
  return 0
}

autoload -Uz add-zsh-hook add-zle-hook-widget
add-zsh-hook precmd _plp_precmd
add-zle-hook-widget line-init _plp_line_init

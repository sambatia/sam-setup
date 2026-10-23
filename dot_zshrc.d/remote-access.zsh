# ~/.zshrc.d/remote-access.zsh — added 2026-07-05 (battery-mode remote access).
# Keeps this Mac reachable for Moshi/SSH-over-Tailscale while on battery,
# where `pmset -b sleep 1` would otherwise sleep it after ~1 min idle.
# Implemented with caffeinate -i (idle-sleep assertion) — deliberately NO
# pmset changes. Display still sleeps (battery-friendly); system stays up.
# Hard macOS limits, not fixable from user space:
#   - closing the lid always sleeps the Mac (unless an external display
#     is attached and powered),
#   - forced sleep (Apple menu > Sleep) still sleeps it,
#   - a drained battery ends remote access.
_REMOTE_ACCESS_PIDFILE="${XDG_STATE_HOME:-$HOME/.local/state}/remote-access/caffeinate.pid"

_remote_access_pid() {
  [[ -f "$_REMOTE_ACCESS_PIDFILE" ]] || return 1
  local pid="$(<"$_REMOTE_ACCESS_PIDFILE")"
  [[ "$(ps -p "$pid" -o comm= 2>/dev/null)" == *caffeinate* ]] || return 1
  print -r -- "$pid"
}

remote-on() {
  command -v caffeinate >/dev/null 2>&1 || { echo "caffeinate not found"; return 1; }
  local pid
  if pid=$(_remote_access_pid); then
    echo "already ON (caffeinate pid $pid)"
    return 0
  fi
  mkdir -p "${_REMOTE_ACCESS_PIDFILE:h}"
  nohup caffeinate -i >/dev/null 2>&1 &
  print -r -- $! > "$_REMOTE_ACCESS_PIDFILE"
  disown %+ 2>/dev/null
  echo "remote access hold ON (caffeinate -i, pid $(<"$_REMOTE_ACCESS_PIDFILE"))"
  echo "reminder: lid must stay open on battery — lid close always sleeps"
}

remote-off() {
  local pid
  if pid=$(_remote_access_pid); then
    kill "$pid" 2>/dev/null
    rm -f "$_REMOTE_ACCESS_PIDFILE"
    echo "remote access hold OFF"
  else
    rm -f "$_REMOTE_ACCESS_PIDFILE" 2>/dev/null
    echo "was not on"
  fi
}

remote-status() {
  local pid
  if pid=$(_remote_access_pid); then
    echo "ON — caffeinate pid $pid ($(pmset -g batt | sed -n '1s/Now drawing from //p'))"
    return 0
  fi
  rm -f "$_REMOTE_ACCESS_PIDFILE" 2>/dev/null
  echo "OFF — normal sleep rules apply (battery sleeps ~1 min idle)"
  return 1
}

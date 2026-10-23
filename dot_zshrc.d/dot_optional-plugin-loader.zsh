# Preflight optional Zsh plugins outside the interactive shell and fail closed.

typeset -gaU TERMINAL_ZSH_PLUGINS_LOADED=()
typeset -gaU TERMINAL_ZSH_PLUGINS_SKIPPED=()

_terminal_zsh_plugin_name_valid() {
  emulate -L zsh
  setopt local_options extended_glob
  (( $# == 1 )) && [[ "$1" == [A-Za-z0-9][A-Za-z0-9._-]# ]]
}

_terminal_resolve_zsh_plugin() {
  emulate -L zsh
  setopt local_options no_aliases

  REPLY=""
  (( $# == 1 )) || return 2
  local requested="$1"
  [[ "$requested" == /* && -e "$requested" ]] || return 1

  local resolved="${requested:A}"
  [[ "$resolved" == /* && -f "$resolved" && -r "$resolved" && ! -L "$resolved" ]] ||
    return 1
  REPLY="$resolved"
}

terminal_preflight_zsh_plugin() {
  emulate -L zsh
  setopt local_options no_aliases pipe_fail

  (( $# == 2 )) || return 2
  local plugin_name="$1"
  local requested_path="$2"
  _terminal_zsh_plugin_name_valid "$plugin_name" || return 2
  _terminal_resolve_zsh_plugin "$requested_path" || return 3
  local plugin_path="$REPLY"

  local zsh_bin="${commands[zsh]:-/bin/zsh}"
  zsh_bin="${zsh_bin:A}"
  [[ -f "$zsh_bin" && -x "$zsh_bin" ]] || return 125
  [[ -f /usr/bin/perl && -x /usr/bin/perl ]] || return 125

  /usr/bin/perl -MPOSIX=:sys_wait_h,setsid -MTime::HiRes=alarm,sleep -e '
    use strict;
    use warnings;

    my ($timeout, @command) = @ARGV;
    my $pid = fork();
    exit 125 if !defined $pid;

    if ($pid == 0) {
      eval { setsid(); 1 } or exit 126;
      open STDIN,  "<", "/dev/null" or exit 126;
      open STDOUT, ">", "/dev/null" or exit 126;
      open STDERR, ">", "/dev/null" or exit 126;
      exec { $command[0] } @command;
      exit 126;
    }

    my $timed_out = 0;
    my $status;
    my $result;
    eval {
      local $SIG{ALRM} = sub { $timed_out = 1; die "timeout\n"; };
      alarm($timeout);
      $result = waitpid($pid, 0);
      $status = $?;
      alarm(0);
    };
    alarm(0);

    if ($timed_out) {
      kill "TERM", -$pid;
      sleep 0.10;
      if (waitpid($pid, WNOHANG) == 0) {
        kill "KILL", -$pid;
        waitpid($pid, 0);
      }
      exit 124;
    }

    exit 125 if !defined $result || $result == -1 || !defined $status;

    # A plugin can launch background workers during source. The probe is
    # disposable, so terminate any descendants still in its private group.
    if (kill("TERM", -$pid) > 0) {
      sleep 0.01;
      kill "KILL", -$pid;
    }

    exit 125 if !WIFEXITED($status);
    exit WEXITSTATUS($status);
  ' 2 \
    "$zsh_bin" -dfic '
      emulate -L zsh
      setopt local_options no_aliases
      source "$1" || exit $?
      typeset function_name function_body
      for function_name function_body in "${(@kv)functions}"; do
        [[ "$function_body" == "builtin autoload -X"* ]] || continue
        autoload +X -- "$function_name" || exit $?
      done
      # Interactive plugins can leave background workers. Replace the probe
      # shell so Zsh does not wait for jobs; the supervisor then cleans the
      # probe process group after this zero-status executable exits.
      exec /usr/bin/true
    ' zsh-plugin-preflight "$plugin_path"
}

_terminal_zsh_plugin_skip() {
  local plugin_name="$1"
  local reason="$2"
  TERMINAL_ZSH_PLUGINS_SKIPPED+=("$plugin_name")
  print -u2 -r -- "zsh-plugin-loader: optional plugin skipped: ${plugin_name} (${reason})"
}

terminal_source_optional_zsh_plugin() {
  emulate -L zsh
  setopt local_options no_aliases

  (( $# == 2 )) || {
    print -u2 -r -- 'zsh-plugin-loader: source requires NAME and PATH'
    return 0
  }
  local plugin_name="$1"
  local requested_path="$2"
  if ! _terminal_zsh_plugin_name_valid "$plugin_name"; then
    _terminal_zsh_plugin_skip invalid-name configuration-error
    return 0
  fi
  if ! _terminal_resolve_zsh_plugin "$requested_path"; then
    _terminal_zsh_plugin_skip "$plugin_name" unavailable
    return 0
  fi
  local plugin_path="$REPLY"

  terminal_preflight_zsh_plugin "$plugin_name" "$plugin_path"
  local preflight_status=$?
  if (( preflight_status != 0 )); then
    local reason='preflight failed'
    (( preflight_status == 124 )) && reason='preflight timed out'
    (( preflight_status == 125 )) && reason='preflight unavailable'
    _terminal_zsh_plugin_skip "$plugin_name" "$reason"
    return 0
  fi

  if ! source "$plugin_path"; then
    _terminal_zsh_plugin_skip "$plugin_name" 'runtime load failed'
    return 0
  fi
  TERMINAL_ZSH_PLUGINS_LOADED+=("$plugin_name")
  return 0
}

if [[ "${ZSH_EVAL_CONTEXT:-}" == toplevel ]]; then
  if (( $# == 3 )) && [[ "$1" == --check ]]; then
    terminal_preflight_zsh_plugin "$2" "$3"
    exit $?
  fi
  exit 2
fi

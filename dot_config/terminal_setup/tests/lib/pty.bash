#!/usr/bin/env bash

# Run a command under a real controlling terminal.
#
# Some checks are only meaningful with a pty attached — an interactive Zsh
# startup, a preflight that must not leave the terminal wedged — and script(1)
# is the portable way to get one.
#
# Terminal allocation can fail for reasons unrelated to the code under test.
# When it does, script(1) exits non-zero having produced nothing, which surfaces
# as a bare `[ "$status" -eq 0 ]` mismatch that reads exactly like a real
# regression. Two suites lost time to that on 2026-09-08.
#
# So: retry once when the command produced no output at all, which is the
# signature of a failed allocation rather than a failed command. A command that
# genuinely fails still fails, because it has said something first, and the
# second attempt leaves $status and $output for the caller's assertions either
# way. On a repeated silent failure the reason is stated outright.
terminal_setup_run_in_pty() {
  local attempt

  case "$(uname -s)" in
    Darwin | Linux) ;;
    *) skip "unsupported script(1) implementation" ;;
  esac

  for attempt in 1 2; do
    case "$(uname -s)" in
      Darwin) run /usr/bin/script -q /dev/null "$@" ;;
      Linux) run /usr/bin/script -q -e -c "$*" /dev/null ;;
    esac
    if [ "$status" -eq 0 ] || [ -n "$output" ]; then
      return 0
    fi
  done

  printf 'pty allocation produced no output twice; script(1) exited %s\n' \
    "$status" >&2
  return 0
}

# Wait for a child to be reaped, bounded. The reap is fast, but a fixed sleep is
# a race the moment the machine is busy.
terminal_setup_wait_for_reap() {
  local pid="$1" waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 50 ]; do
    sleep 0.1
    waited=$((waited + 1))
  done
}

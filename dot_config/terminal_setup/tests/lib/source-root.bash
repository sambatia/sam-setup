#!/usr/bin/env bash

# Resolve the chezmoi source tree that owns these suites.
#
# The tests live in two places: the chezmoi source tree, and the copy chezmoi
# deploys to ~/.config/terminal_setup. Only the source tree carries dot_local
# and dot_zshrc.d, so a relative guess from the deployed copy lands in $HOME and
# every suite that reads a managed source file fails. A suite that fails when
# run the obvious way trains you to ignore it, so the deployed copy locates the
# source tree instead of guessing.
#
# Resolution order: explicit override, the enclosing source tree, then chezmoi
# itself. Prints the absolute root, or returns 1 when none can be found so the
# caller can skip rather than assert against paths that do not exist.
terminal_setup_source_root() {
  local candidate

  if [[ -n "${TERMINAL_SETUP_SOURCE_ROOT:-}" ]]; then
    candidate="${TERMINAL_SETUP_SOURCE_ROOT%/}"
    [[ -d "${candidate}/dot_local" ]] || return 1
    printf '%s\n' "$candidate"
    return 0
  fi

  if candidate="$(cd "${BATS_TEST_DIRNAME}/../../.." 2>/dev/null && pwd -P)" &&
    [[ -d "${candidate}/dot_local" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if command -v chezmoi >/dev/null 2>&1 &&
    candidate="$(command chezmoi source-path 2>/dev/null)" &&
    [[ -n "$candidate" && -d "${candidate%/}/dot_local" ]]; then
    printf '%s\n' "${candidate%/}"
    return 0
  fi

  return 1
}

# Set TS_SOURCE_ROOT for the current test, or skip it with an actionable reason.
# Suites that can fall back to installed copies should call
# terminal_setup_source_root directly instead.
terminal_setup_require_source_root() {
  if ! TS_SOURCE_ROOT="$(terminal_setup_source_root)"; then
    skip "chezmoi source tree not found; set TERMINAL_SETUP_SOURCE_ROOT to its path"
  fi
  export TS_SOURCE_ROOT
}

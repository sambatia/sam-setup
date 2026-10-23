# Refresh Clear-by-Default Design

## Problem

The guarded refresh implementation reloads eligible Herdr panes correctly, but plain `refresh` preserves the worker command, startup-preflight message, and acknowledgement in terminal scrollback. That behavior conflicts with the intended user experience: a successful refresh should finish on a clean prompt.

## Command contract

- `refresh` validates, reloads, and clears every successfully refreshed pane by default.
- `refresh --keep-scrollback` preserves successful refresh output for troubleshooting.
- `refresh --clear` remains a backward-compatible explicit spelling of the default.
- Combining `--clear` and `--keep-scrollback` is a usage error instead of becoming order-dependent.
- `refresh-dry` remains non-mutating while previewing the selected clear policy.
- `clear-panes` and direct controller defaults remain unchanged.

## Execution flow

The Zsh module owns the user-facing default and passes `--clear` to the controller and current-shell worker unless the user chooses `--keep-scrollback`. The controller keeps clearing opt-in for direct invocation, so calling it without flags remains a safe dry run.

The worker performs the startup preflight first. On success it clears the screen and scrollback, then emits the derived acknowledgement using ANSI conceal styling. Herdr can still match the acknowledgement text, while the user sees only the clean login-shell prompt. Failures occur before clearing so their diagnostics remain visible.

## Safety and compatibility

Pane discovery, process revalidation, caller exclusion, worker deadlines, acknowledgement derivation, and exit codes do not change. A clear failure prevents shell replacement. Existing `refresh --clear` callers continue to work, and `--keep-scrollback` provides a deliberate diagnostic path.

## Validation

Tests must prove default clear argument propagation, explicit preservation, conflicting-option rejection, dry-run non-mutation, concealed post-clear acknowledgements, failure diagnostic preservation, and compatibility commands. After deployment, both source and deployed suites must pass, then a real Herdr refresh must acknowledge every eligible pane and leave the panes visually clean.

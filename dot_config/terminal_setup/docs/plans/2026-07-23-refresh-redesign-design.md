# Herdr Refresh Redesign

> **Clear-policy update:** The original preserve-by-default policy in this historical design is superseded by `2026-07-23-refresh-clear-default-design.md`. The safety architecture remains unchanged.

Date: 2026-07-23

## Objective

Make `refresh` reliably reload every eligible Herdr shell pane, including the invoking shell, without disturbing agents, editors, servers, or other foreground applications. Preserve useful scrollback by default, report partial failures, and keep the complete subsystem tested and reproducible in chezmoi.

## Current Failure Modes

The live alias delegates directly to one unmanaged Bash script. That script inspects every pane while it is itself running, only accepts panes whose foreground process list contains Zsh and nothing else, and therefore can skip the invoking pane. It also:

- clears screen and scrollback before validating startup files;
- sources startup files into a live shell before replacement, allowing partial mutation on failure;
- treats pane discovery failures as successful no-op runs;
- does not verify that a submitted pane command actually completed;
- returns success even when individual pane refreshes fail;
- exposes verbose process arguments and working directories;
- has no automated tests or chezmoi ownership.

The July 2026 terminal-tooling change did not create these problems. The refresh module and helper predate it and are outside the committed dotfiles source.

## Considered Approaches

### Patch the monolithic helper

This is the smallest diff, but shell replacement, Herdr discovery, pane classification, user-interface behavior, and reporting remain coupled. The caller problem remains awkward and tests require extensive command mocking.

### Separate shell UX, pane controller, and single-shell worker

This is the selected design. Each layer has one responsibility and a narrow interface. The invoking shell is excluded from remote dispatch through Herdr's authoritative `HERDR_PANE_ID`, then refreshed locally only after every remote operation succeeds.

### Build a native Herdr plugin

A plugin could integrate into Herdr's UI, but it adds installation, manifest, compatibility, and lifecycle surfaces for a shell operation that already has stable CLI primitives. It is unnecessary complexity and would couple the command more tightly to Herdr releases.

## Architecture

### Zsh command module

`~/.zshrc.d/herdr-refresh.zsh` defines functions rather than opaque aliases:

- `refresh` refreshes every eligible remote pane, then replaces the invoking shell last;
- `refresh-dry` validates and previews the same selection without mutation;
- `clear-panes` and `clear-panes-dry` remain compatibility commands with explicit clear-only behavior;
- `refresh --clear` requests clearing only after startup validation;
- `refresh --help` describes scope, eligibility, failure behavior, and recovery.

The function obtains the caller from `HERDR_PANE_ID`. It never sends input to its own busy pane. If the controller reports any failure, it returns nonzero and leaves the current shell intact so diagnostics remain visible. On complete remote success, it runs the current-shell worker as a child; only a successful preflight permits the parent shell to execute `/bin/zsh -l`.

### Herdr pane controller

`~/.local/bin/herdr-refresh-safe-shell-panes` owns Herdr interaction:

1. Validate arguments and required commands.
2. Confirm that pane discovery returns valid JSON.
3. Extract and deduplicate pane IDs.
4. Exclude the caller supplied by `--exclude-pane`.
5. Inspect every pane with `pane process-info` and abort before mutation if inspection is incomplete.
6. Treat a pane as eligible only when every reported foreground process is `zsh` or `-zsh`.
7. In dry-run mode, report the selection without dispatch.
8. In apply mode, recheck each candidate immediately before submitting the fixed worker command atomically with `herdr pane run`.
9. Start concurrent, bounded `herdr pane wait-output` operations for derived acknowledgements that are absent from submitted command text.
10. Return nonzero for dependency, discovery, invalid JSON, dispatch, acknowledgement, or pane failures.

Normal output contains status, pane ID, and a short reason. Process arguments and working directories are not printed. `--verbose` may add safe labels and process names but never raw command lines.

Direct execution defaults to dry-run. Mutation always requires `--apply`.

### Single-shell worker

`~/.local/bin/zsh-refresh-current` is the gate before one shell replacement:

1. Start an isolated interactive login Zsh preflight and require a successful exit.
2. Derive a control-character-free acknowledgement from a validated challenge when requested.
3. Clear screen and scrollback only when `--clear` is explicit and only after preflight succeeds.
4. Enforce an internal preflight deadline shorter than the controller's acknowledgement timeout, preventing late replacement after a reported timeout.
5. Return success without replacing its parent; the already-running interactive shell performs `exec /bin/zsh -l` only after the gate succeeds.

`--check` performs only the preflight, which supports dry runs and focused tests. The worker never sources startup files into the live shell, so a failed preflight cannot partially mutate it.

## Data and Control Flow

```text
refresh
  -> controller --apply --exclude-pane "$HERDR_PANE_ID"
       -> pane list / process-info
       -> pane wait-output DERIVE(RUN:PANE) in the background
       -> pane run 'zsh-refresh-current --challenge RUN:PANE && exec /bin/zsh -l'
  -> if every remote pane succeeds
       -> run zsh-refresh-current as a child preflight
       -> exec /bin/zsh -l only after that child succeeds
  -> otherwise return nonzero and preserve invoking shell
```

## Exit Semantics

- `0`: discovery succeeded and every selected operation completed; a no-eligible-pane dry run is valid.
- `1`: one or more eligible panes failed dispatch, preflight acknowledgement, or refresh.
- `2`: usage, dependency, server, discovery, or invalid-response failure.

The controller prints totals for discovered, eligible, skipped, excluded, refreshed, and failed panes. It must never translate an infrastructure failure into a successful empty result.

## Security and Operational Boundaries

- No pane with an agent, editor, TUI, server, or unknown foreground process is touched.
- Caller identity comes from Herdr's documented `HERDR_PANE_ID`; it is validated as a pane ID before use.
- Session names, pane IDs, timeouts, and acknowledgement challenges are validated before command construction.
- Remote pane commands contain a fixed absolute worker path and generated challenge; arbitrary command input is not accepted, and the derived acknowledgement is absent from terminal input echo.
- Startup output is captured only for failure diagnostics and is not persisted.
- No credentials, shell history, raw command lines, or private task contents are logged.
- No default operation clears scrollback.
- No unrelated `.zshrc` drift is applied or overwritten.
- Herdr cannot reveal partially typed, unsent line-editor input in an otherwise idle shell; users should not invoke bulk refresh while composing commands in other idle panes.

## Source Ownership and Compatibility

Chezmoi will own the Zsh module, controller, worker, tests, and documentation. The source `dot_zshrc` module list will gain only the refresh module entry; the deployed `.zshrc` already contains that entry and will not be broadly re-applied.

The existing command names remain available. The existing helper path remains the controller path, avoiding a compatibility wrapper or migration dependency.

## Testing

Bats fixtures with a fake Herdr executable will cover:

- caller exclusion and current-shell handoff;
- dry-run non-mutation;
- idle-Zsh eligibility and busy-process skipping;
- duplicate and malformed pane data;
- missing dependencies and pane-list failures;
- process-info, dispatch, acknowledgement, and timeout failures;
- partial-failure exit status and complete summary accounting;
- explicit versus default clearing;
- marker and pane-ID validation;
- paths and labels containing spaces;
- compatibility commands and help output.

The worker receives real isolated Zsh preflight tests using a temporary `ZDOTDIR`, including a known-good startup file and a deliberate startup failure. ShellCheck, shfmt, `zsh -n`, Gitleaks, a fake-Herdr integration test, a real dry run, scoped chezmoi diff/apply, and final environment health checks complete validation.

## Rollback

Rollback restores the previous module and helper from source control and removes the worker. Because deployment is scoped to three new or replaced targets and one source-only module-list line, unrelated shell configuration and live processes remain recoverable and untouched.

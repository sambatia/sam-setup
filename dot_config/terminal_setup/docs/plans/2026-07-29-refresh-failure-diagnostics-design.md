# Herdr Refresh Failure Diagnostics Design

## Context

The managed `refresh` workflow now shields the remote worker invocation,
retries only unresolved panes once, validates private acknowledgements, and
fails closed when recovery is exhausted. Those controls reduce the frequency
and blast radius of the observed failure, but a rare terminal failure still
leaves little durable evidence after the controller removes its private
temporary directory.

Fresh local verification on 2026-07-29 found:

- Herdr client and server version `0.7.5`;
- protocol `17` on both sides;
- `compatible: yes`;
- `restart_needed: no`; and
- Homebrew stable version `0.7.5`.

The current Herdr CLI documentation continues to identify `herdr status` as the
supported client/server compatibility check and `pane run` as the preferred
atomic command-submission interface. Herdr's troubleshooting documentation
also warns that stopping a server exits its pane processes, so automated
restart or update behavior is outside the safe refresh boundary.

## Goals

- Preserve enough redacted evidence to diagnose a future intermittent failure.
- Make client/server drift and live read-only compatibility checks easy to run.
- Keep successful `refresh`, `refresh-dry`, and clear operations unchanged.
- Ensure diagnostics can never mask an original failure or make a successful
  refresh fail.
- Bound persistent state by count and secure it against other local users.
- Produce a report that is safe to share without manual redaction.

## Non-goals

- Do not persist commands, pane output, cwd, environment variables, session
  names, socket paths, raw stderr, acknowledgement secrets, or temporary paths.
- Do not add always-on telemetry, a daemon, a scheduler, or a network service.
- Do not automatically update or restart Herdr.
- Do not stop a Herdr server or mutate a pane from the doctor command.
- Do not submit an upstream issue without explicit approval.
- Do not change acknowledgement, retry, clearing, or shell-replacement
  semantics.

## Considered Approaches

### 1. Failure-only local journal plus a read-only doctor

Persist one small structured record only when a mutating refresh fails. Retain
the ten newest records under `XDG_STATE_HOME`, with a private directory and
private files. Add `refresh-doctor` for supported client/server status, current
shell startup validation, and non-mutating pane discovery.

This is the chosen approach. It improves diagnosis while keeping success
silent, state bounded, and the operational surface small.

### 2. Always-on metrics and scheduled probes

Run periodic checks and retain success/failure history. This could reveal
failure rates, but it adds background activity, more persistent state, launch
configuration, and false alarms for a personal local terminal workflow. The
observed weekly fault does not justify that control plane.

### 3. Upstream-only reporting with no local evidence

Open a Herdr issue using the existing observations and make no local changes.
An upstream fix remains desirable, but without a bounded diagnostic record the
next variant may again be difficult to characterize. External issue creation
also requires separate explicit authorization.

## Architecture

### `refresh-doctor`

Create one managed Bash executable with two interfaces:

```text
refresh-doctor
refresh-doctor --record --component COMPONENT --reason REASON ...
```

The default interface is strictly read-only. It:

1. checks the required executables;
2. prints a sanitized Herdr client/server status without its socket path;
3. runs the controller in dry-run mode while suppressing its output;
4. runs the current-shell worker in validation-only mode; and
5. validates and prints the newest redacted failure record, if one exists.

It never invokes `pane run`, `pane send-*`, server stop/update commands, clear,
or shell replacement. A failed check produces a nonzero result and an
actionable label, while raw child output is withheld from the share-safe
summary.

The internal `--record` interface accepts only enumerated components, strictly
validated reason tokens, exit status, and nonnegative summary counts. It is
called by the controller or Zsh orchestration after an original failure.

### Persistent record

Records live at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/herdr-refresh/failure-*.json
```

Relative `XDG_STATE_HOME` values are ignored per the XDG Base Directory
contract. The fallback requires an absolute `HOME`.

The journal directory must be a real directory owned by the current UID with
mode `0700`. Each record must be a regular, non-symlink file owned by the
current UID with mode `0600`. Publication uses a private temporary file and an
atomic hard link so an existing record is never overwritten.

Schema version 1 contains only:

```json
{
  "schema_version": 1,
  "recorded_at": "2026-07-29T18:00:00Z",
  "component": "controller",
  "reasons": ["acknowledgement-timeout"],
  "exit_status": 1,
  "herdr_client_version": "0.7.5",
  "counts": {
    "discovered": 34,
    "eligible": 23,
    "excluded": 1,
    "skipped": 10,
    "refreshed": 22,
    "failed": 1
  }
}
```

The writer accepts only `[a-z0-9-]` reason tokens and numeric counts. It never
accepts arbitrary diagnostic text. After atomic publication it removes only
matching `failure-*.json` files beyond the ten newest, inside the validated
private directory.

Journal creation is best-effort. If recording fails, the refresh retains its
original exit status and emits only a short warning. A successful record adds
one instruction to run `refresh-doctor`; it does not print a private path.

### Controller integration

The controller accumulates normalized terminal reason tokens while retaining
its existing human diagnostics. On an apply-mode failure it calls
`refresh-doctor --record` once with the unique reason set and final counters.
Dry runs and successful applies never call the writer.

Infrastructure failures after dependency validation use normalized reasons
such as `pane-discovery-failed`, `pane-schema-invalid`, and
`process-inspection-failed`. Pane failures use the existing reason vocabulary,
including `dispatch-failed`, `acknowledgement-timeout`,
`acknowledgement-invalid`, and `changed-before-retry`.

### Zsh integration

The controller records remote or controller failures. If the controller
succeeds but the invoking shell's local worker fails, the `refresh` function
records one `current-shell` event with a normalized
`current-shell-refresh-failed` reason. Dry-run validation does not persist a
record.

The diagnostic helper remains optional at runtime: absence or failure is
reported after the original error but never changes that error's status.

## Security and Privacy

- `umask 077` applies throughout record creation.
- Directory ownership, type, and exact mode are checked before every write.
- Record ownership, type, exact mode, schema, and allowed values are checked
  before display.
- Raw Herdr responses are neither stored nor included in the share-safe doctor
  report.
- The doctor strips the Herdr socket path and does not print pane identifiers.
- There is no network transmission.
- Rotation targets only validated, controlled filenames below the validated
  journal directory.

## Error Handling

- Diagnostics failure never converts refresh success to failure.
- Diagnostics failure never replaces the refresh's original nonzero status.
- An invalid journal directory prevents recording rather than weakening
  permissions.
- A malformed or unsafe latest record is rejected and causes the doctor to
  report a failed journal check.
- A missing journal is normal and reported as `latest_failure: none`.
- A Herdr status, pane dry-run, or shell preflight failure makes the doctor
  nonzero without exposing raw output.

## Testing

Focused Bats coverage will prove:

- help and default doctor mode never mutate panes;
- recording creates a valid schema-1 JSON file with `0700/0600` permissions;
- arbitrary components, reasons, statuses, and counts are rejected;
- relative `XDG_STATE_HOME` is ignored;
- successful and dry-run refreshes create no record;
- a permanent controller failure creates exactly one redacted record;
- a current-shell failure creates a distinct record;
- raw command, cwd, environment, socket, and stderr sentinels never persist;
- rotation retains exactly the ten newest matching records;
- doctor output excludes the socket and pane IDs;
- doctor reports client/server, pane discovery, shell preflight, and latest
  record status; and
- a doctor check failure returns nonzero without mutation.

The existing refresh and repository test suites, ShellCheck, `shfmt`, Zsh
syntax validation, Actionlint, Typos, and `git diff --check` remain required.

## Deployment and Rollback

Apply only:

```text
~/.local/bin/refresh-doctor
~/.local/bin/herdr-refresh-safe-shell-panes
~/.zshrc.d/herdr-refresh.zsh
```

The updated Zsh function is already loaded by existing shells but must be
re-sourced to gain local-worker journaling. The controller and doctor are
resolved by path on every call, so their deployed updates are immediate.

Rollback restores the prior three managed sources and applies only those
targets. Existing journal files are harmless bounded state; they are not
deleted automatically during rollback.

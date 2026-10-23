# Herdr Refresh Targeted Recovery Design

**Date:** 2026-07-29

## Problem

The managed `refresh` command can fail after most panes have refreshed:

```text
FAIL w1:p24 reason=acknowledgement-failed
```

The acknowledgement is not the root failure. The local `preexec` trace recorded
two separate `refresh` runs in which Herdr delivered the worker command without
its leading slash:

```text
Users/sam/.local/bin/zsh-refresh-current ...
```

All peer panes in those runs received the intended absolute path:

```text
/Users/sam/.local/bin/zsh-refresh-current ...
```

The affected pane therefore could not start the worker or publish its private
acknowledgement. A whole-fleet rerun refreshed successful panes again and moved
the same failure to a different pane. The probability that at least one pane
hits a rare transport fault grows with the number of eligible panes.

Herdr 0.7.5 is the current stable Homebrew release on this machine. Its current
[CLI documentation](https://herdr.dev/docs/cli-reference/) says `pane run`
honors bracketed-paste mode and submits command text plus Enter atomically. It
also recommends `pane run` over separate `send-text` and `send-keys` calls.
The controller should keep the supported high-level API while defensively
handling an observed delivery fault.

## Goals

- Preserve the strict contract: success means every selected pane produced a
  valid acknowledgement.
- Prevent the observed leading-character loss from corrupting the worker path.
- Recover one transient dispatch or missing-acknowledgement failure without
  rerunning panes that already succeeded.
- Make a duplicate or delayed delivery safe within one controller run.
- Preserve the existing complete discovery pass, immediate eligibility
  rechecks, private acknowledgement validation, and silent public success UX.
- Keep first-round acknowledgement waits concurrent so healthy fleet latency
  remains bounded by one timeout window rather than pane count.
- Improve final diagnostics without exposing command contents, working
  directories, or process arguments.

## Non-goals

- Do not replace Herdr's supported `pane run` API with `send-text` plus Enter.
- Do not add a shell signal handler, FIFO, daemon, or persistent control plane.
- Do not retry malformed or security-invalid acknowledgement files.
- Do not make best-effort success hide an unresolved pane.
- Do not change Zsh startup validation, clear semantics, or the public function
  arguments.
- Do not update, patch, fork, or replace Herdr itself.

## Chosen Design

### 1. Shield the worker invocation

The submitted compound command starts with a disposable, stderr-suppressed
no-op followed by a semicolon:

```text
 command true 2>/dev/null; /absolute/path/to/zsh-refresh-current ...
```

The leading space is the first sacrificial character. If an input layer trims
leading whitespace and then drops the first non-whitespace character, only the
disposable command is damaged. The semicolon still allows the untouched worker
invocation to run. The worker remains an absolute, shell-escaped path.

This shield is intentionally not an `&&` chain: damage to the disposable
prefix must not suppress the worker. The possible error from a damaged prefix
is redirected to `/dev/null`; the worker's own diagnostics remain visible.

### 2. Retry only unresolved panes once

The controller performs at most two rounds:

1. Dispatch every eligible pane and wait for acknowledgements concurrently.
2. Recheck and redispatch only panes whose command was not acknowledged.

Successful panes never enter the second round. This changes the residual
fleet-wide failure model from "rerun all N panes" to "retry only k unresolved
panes," where `k` is normally one.

One retry is the fixed default rather than a new public tuning option. More
attempts would increase ambiguity and latency without evidence that they are
needed. A persistent second-round failure remains visible and nonzero.

### 3. Reuse the same acknowledgement identity

Both attempts for a pane reuse the same challenge, digest, and acknowledgement
path. This is the idempotency key for the controller run.

The worker already refuses a pre-existing acknowledgement path and publishes a
new acknowledgement with an atomic hard link. If a delayed first delivery and
the retry overlap, both may validate, but only one worker can publish the
shared acknowledgement and continue through `&& exec /bin/zsh -l`. The loser
fails acknowledgement publication and does not replace the shell.

The controller never removes a per-pane acknowledgement before the complete
run ends. A late valid acknowledgement can therefore satisfy the retry wait
without permitting two successful replacements.

Immediately before recovery reinspection and again immediately before
redispatch, the controller checks the stable acknowledgement path without
waiting. A valid acknowledgement that arrived between rounds completes the
pane without another injection. An invalid late acknowledgement fails with the
same terminal integrity error as an invalid first-round acknowledgement.

### 4. Classify retryable and terminal failures

Acknowledgement waiting returns distinct states:

- valid acknowledgement: success;
- no acknowledgement before the deadline: retryable once;
- present but invalid acknowledgement: terminal security/integrity failure.

An acknowledgement is invalid if it is a symlink, not a regular file, has a
mode other than `0600`, has the wrong size, or contains the wrong digest.
Invalid files are never retried because legitimate publication is atomic and a
malformed file is not a transient partial-write state.

A dispatch command that returns nonzero remains acknowledgement-ambiguous. The
controller waits for the same acknowledgement before deciding it failed,
because a local response failure does not prove the pane rejected the request.
If no acknowledgement arrives, that pane is eligible for the one retry.

Before retrying, the controller repeats the existing full foreground-process
check. A pane that is no longer exclusively idle Zsh is not injected again and
the operation fails safely. An unavailable or malformed process response also
prevents retry.

## Data Flow

For each eligible pane:

1. Allocate one private acknowledgement path and challenge.
2. Construct one shielded, safely quoted remote command.
3. Recheck that the complete foreground process set is idle Zsh.
4. Submit with `herdr pane run`.
5. Wait concurrently for the exact acknowledgement digest.
6. Mark valid acknowledgements successful.
7. Carry only missing acknowledgements or unacknowledged dispatch errors into
   the recovery round.
8. Recheck each recovery candidate and submit the identical command.
9. Wait concurrently again.
10. Return nonzero if any pane still lacks a valid acknowledgement or produced
    an invalid acknowledgement.

The invoking pane remains excluded and is refreshed locally only after the
controller returns complete success, as before.

## Output Contract

- Public `refresh` and `clear-panes` remain silent when the first round or
  recovery round succeeds.
- Direct non-quiet controller runs show a `RETRY` line only for recovery
  candidates and may annotate a recovered `OK` with its attempt number.
- A terminal missing acknowledgement reports the pane and attempt count.
- A malformed acknowledgement reports a distinct integrity failure.
- The existing summary fields retain their meanings: a recovered pane counts
  once as refreshed; only terminal failures count as failed.

## Testing

The Bats fake Herdr transport will support deterministic fault injection.
Focused tests will prove:

- dropping the submitted command's first character does not corrupt the worker
  invocation;
- a first-round missing acknowledgement retries that pane and succeeds;
- a successful peer pane is dispatched only once while another pane retries;
- both attempts reuse the exact acknowledgement path and challenge;
- a valid acknowledgement arriving between rounds prevents redispatch;
- a permanent missing acknowledgement makes exactly two attempts and exits
  nonzero;
- malformed acknowledgements are rejected without retry;
- recovery-round eligibility changes prevent redispatch;
- quiet mode stays silent after successful recovery;
- acknowledgement waits remain concurrent within each round.

The full existing Bats suite, ShellCheck, `shfmt -d`, `git diff --check`, Typos,
and the repository's local CI-equivalent checks must pass before deployment.

## Deployment and Rollback

Only managed source files are edited. The production controller is deployed
with an explicit `chezmoi apply` target after a reviewed `chezmoi diff`.
The deployed terminal-tooling README already had unrelated source drift before
this change, so its updated source documentation is not applied as part of this
deployment. Unrelated README and `.zshrc` drift remains untouched.

Rollback is the normal scoped chezmoi rollback: restore the prior controller
source revision and apply only
`~/.local/bin/herdr-refresh-safe-shell-panes`. No Herdr server restart, shell
restart, package installation, credential change, or external mutation is
required.

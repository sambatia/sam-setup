# Silent Herdr Refresh Acknowledgement Design

Date: 2026-07-23

## Objective

Make a successful `refresh` leave only the newly started shell prompt. No
acknowledgement text, status marker, or terminal concealment sequence may be
written to a refreshed pane, even transiently.

Failures must remain observable, every eligible pane must still be confirmed
before the invoking shell is replaced, and acknowledgement latency must remain
bounded and concurrent.

## Root Cause

The current worker writes `herdr-refresh-ok-<digest>` into each pane and wraps
the marker in SGR 8 (conceal) after clearing. Ghostty implements SGR 8, but
Herdr 0.7.5 stores the terminal cell's `invisible` attribute and then renders an
invisible cell by copying its background into the foreground. When the pane
background is transparent or unspecified, there is no background color to
copy, so Ratatui receives ordinary visible text.

The behavior is present in the current stable Herdr release and on its current
main branch:

- Herdr 0.7.5 renderer:
  <https://github.com/ogulcancelik/herdr/blob/ef4c23f5775bb8cfec05f05d0844226ff959a07a/src/pane/terminal.rs#L2601-L2603>
- Herdr 0.7.5 release:
  <https://github.com/ogulcancelik/herdr/releases/tag/v0.7.5>
- Ghostty 1.3.1 glyph concealment:
  <https://github.com/ghostty-org/ghostty/blob/332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28/src/renderer/generic.zig#L2918-L2928>

This makes terminal-rendered acknowledgements unsuitable as a correctness
protocol, regardless of whether the bytes are intended to be visible.

## Considered Approaches

### Keep the terminal marker and erase it afterward

The controller could continue waiting for pane output while the worker prints,
delays, and then clears the marker. This remains visibly racy, can lose fast
output, and violates the requirement that success be silent even transiently.

### Patch or fork Herdr

Mapping `CellStyle.invisible` to Ratatui's hidden modifier would repair Herdr's
rendering. A private build would add release, signing, packaging, and upgrade
maintenance, while the refresh protocol would still depend on terminal
scrollback and rendering. An upstream report may be useful, but a fork is not
the right dependency for this command.

### Use controller-owned acknowledgement files

This is the selected design. Herdr panes and the controller run on the same
machine, so a private filesystem channel provides durable, non-rendered
completion state without adding a service, package, socket protocol, or custom
Herdr build.

## Architecture

### Controller

For an apply run, the controller creates a unique temporary directory and
explicitly restricts it to mode `0700`. For each eligible pane it creates:

- a unique, not-yet-existing acknowledgement path inside that directory;
- a validated challenge;
- the expected SHA-256 digest of that challenge.

It passes the acknowledgement path and challenge to the fixed worker command.
After dispatch, a bounded background waiter polls only that exact path and
accepts success only when:

1. the path is a regular file and not a symbolic link;
2. the file has exactly one expected digest and no additional content;
3. its permissions are `0600`.

Waiters run concurrently, preserving one-timeout-window aggregate latency.
Unlike scrollback output, an acknowledgement file persists until the
controller validates it, so there is no fast-output race and no need to start
the waiter before dispatch.

The temporary directory and every acknowledgement are removed by the
controller's existing signal-safe cleanup path.

Apply mode also accepts an internal `--quiet` flag used by the public
`refresh` and `clear-panes` functions. Quiet mode suppresses discovery,
progress, and success output but never suppresses errors. Direct controller
invocations and all dry runs remain informative.

### Worker

The worker accepts `--ack-file PATH` only with a valid `--challenge`. It rejects
pre-existing acknowledgement paths and paths whose parent is not a private
directory owned by the current user.

After successful preflight and any requested clear, it:

1. derives the challenge digest;
2. creates a temporary file in the acknowledgement directory with mode `0600`;
3. writes exactly the digest plus a newline;
4. atomically publishes it with a same-directory, no-clobber hard link.

The worker writes no acknowledgement or concealment bytes to standard output.
It is silent on every successful apply path, including
`--keep-scrollback`. Failure diagnostics remain unchanged.

`--clear-only` uses the same acknowledgement path so the compatibility command
retains confirmed completion without terminal markers.

### Zsh command module

The public command contract does not change:

- `refresh` clears by default and leaves a clean new prompt;
- `refresh --keep-scrollback` preserves prior scrollback by explicit choice,
  but adds no successful refresh status;
- `refresh-dry` remains intentionally informative and non-mutating;
- `clear-panes` retains clear-only compatibility.

The module passes the controller's internal `--quiet` option only for mutating
public commands. No new dependency or public command option is added.

## Data Flow

```text
refresh
  -> controller creates private run directory
  -> controller rechecks each eligible pane
  -> controller dispatches:
       worker --ack-file UNIQUE_PATH --challenge UNIQUE_VALUE
       && exec /bin/zsh -l
  -> worker validates startup
  -> worker clears the pane
  -> worker atomically writes EXPECTED_DIGEST to UNIQUE_PATH
  -> remote shell is replaced
  -> concurrent controller waiter validates file, content, and mode
  -> controller removes private run directory
  -> invoking shell is validated, cleared, and replaced last
```

## Failure Semantics

- Preflight or clear failure: no acknowledgement is published and the remote
  shell is not replaced.
- Acknowledgement validation or publication failure: the worker returns
  nonzero, the remote shell is not replaced, and diagnostics remain visible.
- Dispatch failure: the pane is reported failed without waiting for a file.
- Timeout, malformed content, wrong mode, symlink, or stale file: the pane is
  reported `acknowledgement-failed`.
- One failed pane does not prevent dispatch attempts to other eligible panes.
- Any remote failure prevents replacement of the invoking shell.

Exit codes and summary counters remain compatible with the existing command.

## Security and Compatibility

- The acknowledgement directory is controller-owned, unique, and mode `0700`.
- Files are unique, created without clobbering, and mode `0600`.
- Paths are generated internally; callers cannot supply arbitrary remote
  commands through this interface.
- Challenge and digest validation remain strict.
- Symlinks and pre-existing final paths are rejected.
- Bash 3.2 and standard macOS utilities remain the compatibility baseline.
- No daemon, network listener, Homebrew package, credential, or elevated
  permission is introduced.

## Testing

The test-first change will prove:

- successful worker acknowledgement produces no stdout marker or SGR 8 bytes;
- successful apply mode produces no controller or worker output;
- quiet mode still exposes failures while dry runs remain informative;
- the worker atomically publishes the exact digest with mode `0600`;
- no acknowledgement is published before successful preflight and clear;
- unsafe, pre-existing, mismatched, or insufficiently private paths fail;
- the controller never invokes `herdr pane wait-output`;
- each eligible pane gets a unique acknowledgement path and challenge;
- concurrent success, dispatch failure, malformed file, and timeout accounting
  remain correct;
- controller, worker, and Zsh module behavior remains Bash 3.2/Zsh compatible;
- the complete existing refresh suite has no regressions.

Deployment validation will compare managed source and live targets byte for
byte, run a real dry run, then exercise controlled eligible Herdr panes and
inspect pane output for zero `herdr-refresh-ok-` occurrences.

## Rollback

Restore the controller, worker, tests, and documentation from the previous Git
revision, then apply only the two managed executable targets with chezmoi.
No persistent acknowledgement state survives a run, and no Herdr or Ghostty
configuration changes are required.

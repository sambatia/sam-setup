# Network diagnostics

`net-health` is now a standalone package. Chezmoi owns its thin launcher and
Zsh completion, not the application implementation or its Python dependencies.
The source project is `~/Projects/net-health`; see its README and `docs/` for
the public contract, development and release guidance.

```sh
net-health --quick                       # No throughput tests; 35-second budget
net-health                               # Apple capacity test; 100-second budget
net-health --full                        # Longer checks; 225-second budget
net-health --full --speed-provider ookla  # Explicit public bandwidth measurement
net-health --librespeed                  # Explicit alternative public provider
net-health --quick --json                # One JSON document, no progress
net-health --no-progress                 # Styled report without animation
net-health --plain                       # Plain report
net-health --no-speed                    # Skip Apple and public speed tests
net-health doctor                       # Runtime/output/helper discovery; no probes
net-health --version
```

Quick mode excludes bandwidth tests. Normal/full may saturate the connection.
Public providers are no longer selected implicitly; this is an intentional
privacy/cost change. `--iperf HOST --iperf-port PORT` explicitly authorizes that
endpoint only; it conflicts with quick mode. No provider is silently substituted.

Rich is required by the package. Interactive terminals get progress and a styled
report; `--no-progress` keeps the report but disables animation. Redirected
stdout, `--plain`, `NO_COLOR` and `TERM=dumb` select plain output. JSON never
contains progress. An unexpected Rich failure produces a safe diagnostic and
plain fallback. Progress counts completed checks, not invented speed percentages.

Exit 0 means PASS or noncritical WARN; 1 means observed critical health failure;
2 means invalid invocation, inability to perform required core diagnostics, or
an internal error; 130 means interruption. Missing optional providers produce
unavailable evidence and WARN, not an internal error. ICMP filtering and partial
route visibility alone do not prove an outage.

net-health does not save or upload reports or install tools at runtime. Probes
necessarily contact their targets. Providers may retain measurements under
their terms; Ookla reported persisted results during the authorized local test.
The app discards result URLs, ISP/interface/server metadata and raw output.
It does not accept provider terms automatically or disable TLS verification.

## Ownership and maintenance

| Component | Owner |
| --- | --- |
| `~/.local/bin/net-health` and `_net-health` completion | Chezmoi, thin dispatch only |
| Application, Python 3.14 and Rich | Reviewed wheel in `~/.local/share/net-health`, private uv tool environment |
| Ookla and iperf3 | Existing Homebrew owner |
| LibreSpeed | Existing mise owner |
| Apple networkQuality | macOS |

`~/.local/share/net-health/current` points to a verified hash-addressed stage.
The stage owns its explicit uv-managed Python and locked dependencies; generic
Homebrew `python3` is not involved. A missing package fails with an actionable
message instead of falling back to a different implementation.

This unpublished local artifact is intentionally pinned outside the default
uv tool directory. `update-all` preserves it while updating its existing
Homebrew/mise helpers. It does not publish or fetch an unapproved package name.
Upgrade only from a reviewed wheel using the project's staging/activation tools.
There is no self-updater or service. Do not install another `net-health` into PATH.

## Verification and recovery

Run `net-health --version` and `net-health doctor --json` without network tests.
Use the standalone project's offline suite for behavior and PTY acceptance;
the legacy Chezmoi application/UI/test files have been retired.

The migration preserved the former launcher, app, UI, test, documentation and
completion in a private dated bundle under `~/.local/state/net-health/backups`.
The project's migration summary records its exact directory and hashes.
Restore only those files if a full legacy rollback is needed; inspect current
diffs first so later edits are not overwritten. Legacy rollback restores the old
interpreter dependency too, so it is a recovery route, not a cure for the bug.

For a packaged rollback, explicitly activate the verified previous stage's
receipt with `tools.activate_stage`; both stages remain on disk. Reapply only
the launcher and completion targets with Chezmoi. Never run broad cleanup,
uninstall shared Python, remove provider tools, or reset unrelated repositories.

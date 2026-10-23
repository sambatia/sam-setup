# Fail-Closed Zsh Plugin Loading Design

Date: 2026-08-04

## Objective

Keep every new interactive Zsh usable when an automatically updated optional
plugin is missing, corrupt, incomplete, or hangs during initialization. Preserve
working autocomplete, autosuggestions, and syntax highlighting when their
installed payloads are healthy.

## Incident and Root Cause

Homebrew upgraded `zsh-autocomplete` to 26.08.03 from a GitHub tag archive.
That release introduced a required `z-async` Git submodule, but the installed
archive omitted the submodule contents. The plugin registered a delayed
autoload function successfully during startup; every subsequent ZLE redraw then
failed while trying to load the absent function. Both Terminal.app and iTerm2
were affected because the fault lived in shared Zsh configuration.

The immediate repair restored the exact referenced `z-async` commit inside the
versioned Homebrew keg. That repair is intentionally temporary: reinstalling or
upgrading the formula replaces the keg.

## Constraints

- An optional plugin failure must never prevent typing or executing commands.
- A failed plugin must be rejected before it mutates the live interactive shell.
- Validation must catch delayed autoload failures, not only a missing top-level
  plugin file or a nonzero `source` status.
- Validation must be bounded so a hung plugin cannot hang shell startup.
- Healthy plugins must continue to come from Homebrew; do not introduce a
  second plugin manager, silently pin stale code, or vendor third-party source.
- Preserve the current chezmoi-managed configuration and the existing
  `zsh-refresh-current` safety architecture.
- Do not expose secrets, commit changes, or overwrite unrelated worktree edits.

## Considered Approaches

### 1. Bounded isolated preflight with fail-closed loading

Before sourcing an optional plugin into the interactive shell, source it in a
clean child Zsh and force every autoload stub created by the plugin to resolve.
Run the child under a short watchdog. Source the plugin in the parent only when
the child exits successfully. Otherwise, skip it and print one concise warning.

This is selected. It detects the incident's delayed missing dependency, syntax
and immediate initialization failures, and hangs while preserving package-manager
updates and normal Zsh behavior.

### 2. Pin known-good plugin copies outside Homebrew

This prevents Homebrew from changing startup code, but trades visible update
failures for silent staleness and creates a second ownership path. It also does
not protect against local corruption or future Zsh incompatibility.

### 3. Remove `zsh-autocomplete`

Standard Zsh completion would be maximally simple, but removing a useful feature
is unnecessary when the plugin can be isolated safely.

## Architecture

### Optional plugin loader

Add a chezmoi-managed helper at
`~/.zshrc.d/.optional-plugin-loader.zsh`. It exposes:

- `terminal_preflight_zsh_plugin NAME PATH`, which validates the name and
  absolute regular readable plugin path, resolves the active Zsh executable,
  and runs the isolated probe under a bounded watchdog;
- `terminal_source_optional_zsh_plugin NAME PATH`, which calls the preflight,
  sources only a healthy plugin, records loaded and skipped plugin names in
  global arrays, and emits a stable one-line diagnostic on failure; and
- a top-level `--check NAME PATH` interface for tests and health tooling.

The isolated probe starts interactive Zsh without global or user startup files,
sources the candidate, enumerates functions whose bodies are still
`builtin autoload -X…` stubs, and forces each one to load with `autoload +X`.
Interactive mode ensures plugins that gate their initialization on that option
cannot evade the probe. This turns delayed missing function files such as
`z-async` into a pre-startup failure.

The watchdog uses the system Perl already required by `zsh-refresh-current` to
fork the probe into a private session, enforce a two-second alarm, terminate
then kill a stuck child process group, reap it, and return status 124 on timeout.
Detaching the controlling terminal prevents interactive job-control coupling
with the parent shell. Child stdout and stderr are suppressed; the interactive
shell prints only normalized loader diagnostics. After successful validation,
the child replaces itself with `/usr/bin/true`; this bypasses interactive
job-exit waiting so the supervisor can terminate any plugin workers remaining
in the child's private process group.

### Startup order

`.zshrc` sources the loader before any optional plugin. It preflights and loads
`zsh-autocomplete` before Oh My Zsh, matching upstream's requirement that it be
loaded before `compdef` calls. If autocomplete is rejected, Oh My Zsh initializes
standard Zsh completion normally. Autosuggestions and syntax highlighting are
preflighted and loaded after Oh My Zsh, preserving their established order.

Loader functions are removed after plugin setup; the loaded/skipped status
arrays remain available to diagnostics.

### Refresh and update validation

`zsh-refresh-current` syntax-checks the new helper explicitly, then performs its
existing isolated login-shell preflight. A skipped plugin writes to stderr, so
the existing no-stderr invariant rejects a degraded shell for automated pane
replacement while the actual interactive shell remains usable.

`update-all` adds the existing `zsh-refresh-current --check` command as a final
required shell validation when the worker is installed. This surfaces a broken
Homebrew plugin in the same update run. It reports but does not attempt a broad
Homebrew rollback; startup isolation is the safe containment boundary.

### Package state

After the guard is live, refresh Homebrew metadata and reinstall
`zsh-autocomplete` from the current official package. Fresh signed metadata on
2026-08-04 still selected stable 26.08.03, and reinstalling its bottle
reproduced the missing `z-async` dependency. Homebrew's `--HEAD` fetch resolved
to commit `24c4ea8`, exactly the upstream 26.08.03 tag, and initialized the
release's submodules. Installing that source through Homebrew removes the
untracked Cellar repair while preserving package ownership and working
autocomplete. The startup health gate remains authoritative for later package
changes.

## Error Handling and Security

- Relative paths, broken links, unreadable targets, and non-regular targets are
  rejected before execution. Package-manager symlinks are resolved once, then
  the same canonical regular file is preflighted and sourced.
- Plugin names are restricted to a conservative identifier grammar before they
  appear in diagnostics.
- Preflight child output is discarded so third-party initialization cannot
  leak environment-derived data through startup diagnostics.
- The watchdog reaps both child and timeout paths; no background supervisor is
  left behind.
- A timeout, signal, parse error, source error, or unresolved autoload produces
  one normalized warning and skips only that plugin.
- No cache is used. Every shell validates the current on-disk payload, avoiding
  stale-positive cache entries after same-version reinstalls or corruption. The
  measured autocomplete probe cost is approximately 0.01 seconds, small beside
  the current 0.3–0.6 second login-shell startup.

## Testing

Add focused Bats tests for:

- healthy plugin preflight and source;
- missing and broken-link rejection plus canonical package symlink handling;
- delayed missing autoload dependency rejection before parent mutation;
- a valid delayed autoload dependency;
- syntax/source failure isolation;
- timeout handling and child cleanup;
- independent failure where later healthy plugins still load;
- production `.zshrc` use of the loader and upstream-compatible ordering;
- `zsh-refresh-current` syntax and runtime checks; and
- update-all's final required shell-health invocation.

Run Zsh syntax checks, focused Bats suites, ShellCheck where applicable, the
complete terminal/update-all suites, scoped chezmoi diff/apply verification, a
clean login-shell check, and an actual pseudo-terminal keystroke test.

## Rollback

Restore the reviewed `.zshrc`, refresh worker, update-all validation, tests, and
documentation changes through their owning source repositories, then apply only
the affected chezmoi targets. Package rollback is independent: reinstalling the
current Homebrew formula restores its owned keg. Never restore the temporary
untracked files inside an obsolete keg.

## References

- [zsh-autocomplete installation](https://github.com/marlonrichert/zsh-autocomplete)
- [Homebrew zsh-autocomplete formula](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/z/zsh-autocomplete.rb)
- [chezmoi apply reference](https://www.chezmoi.io/reference/commands/apply/)
- [Zsh autoloading functions](https://zsh.sourceforge.io/Doc/Release/Functions.html#Autoloading-Functions)

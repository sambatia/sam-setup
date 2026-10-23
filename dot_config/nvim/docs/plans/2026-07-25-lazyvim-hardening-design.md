# LazyVim Update Hardening Design

## Context

The production upgrade already provides a daily, asynchronous safe-update policy with lockfile
snapshots, validation, logging, and rollback. A follow-up audit found five narrow reliability gaps:

1. the startup eligibility guard reads `lazy.nvim`'s removed `spec.errors` field instead of current
   `spec.notifs` diagnostics;
2. the update transaction does not execute the existing runtime smoke suite or CodeCompanion health
   check;
3. rollback restores plugin revisions but does not realign Tree-sitter parsers afterward;
4. an update launched during `VimLeavePre` can overlap another interactive Neovim process; and
5. dry-run creates state directories and an empty log despite promising a read-only eligibility
   check.

CodeCompanion also follows its moving default branch even though its supported installation guidance
recommends a compatible release range. The existing configuration comment demonstrates a token on a
command line, which can leak into shell history.

## Decision

Keep the existing architecture and harden its boundaries rather than introducing a scheduler,
service, or second update mechanism.

- Centralize Lazy spec error interpretation in `config.lazy_validation`. Treat only
  `vim.log.levels.ERROR` diagnostics as invalid; warnings remain visible but do not block updates.
- Pass the initiating Neovim PID to the detached updater. The updater waits briefly for that process
  to exit and then refuses to run if any other user-owned `nvim` process remains.
- Make dry-run strictly observational. State directories, lock files, snapshots, and logs are created
  only for a real update attempt.
- Extend the transaction validation sequence with the real runtime smoke suite and a loaded
  CodeCompanion health check.
- On rollback, restore locked plugin revisions and then rerun the Tree-sitter verifier before the
  final startup check.
- Pin CodeCompanion to the compatible `^19.0.0` release line and retain lockfile reproducibility.
- Replace the inline-token Keychain example with an interactive `security ... -w` prompt.

## Transaction

For a real update:

1. verify prerequisites, repository safety, elapsed interval, parent-process exit, and session
   exclusivity;
2. acquire the update lock and create private state/log/snapshot paths;
3. validate baseline startup and Lazy spec diagnostics;
4. snapshot `lazy-lock.json`;
5. run `Lazy! update`, validate the lockfile, and run `Lazy! sync`;
6. verify Tree-sitter parsers and queries;
7. validate startup, plugin specs, update policy, runtime smoke behavior, scoped Neovim health, and
   loaded CodeCompanion health;
8. keep the new lockfile for review on success;
9. on any post-snapshot failure, restore the previous lockfile, restore plugin revisions, realign
   Tree-sitter parsers, and revalidate startup.

## Safety Properties

- Network operations remain detached from interactive startup.
- Updates remain rate-limited and cannot run while the configuration worktree is unsafe.
- A dirty lockfile after success is deliberate: it creates a review boundary and blocks another
  automatic update until the change is accepted or reverted.
- Dry-run leaves no filesystem state.
- Existing plugin roles, mappings, and LazyVim behavior remain unchanged.
- No credential is stored in tracked configuration or passed as a literal shell argument.

## Alternatives Rejected

- A daily `launchd` updater duplicates lifecycle logic and can run without useful editor context.
- Updating on every startup adds network latency and increases exposure to upstream breakage.
- Replacing the current updater would enlarge the change surface without improving the identified
  failure modes.
- Pinning every plugin would make maintenance costly; the targeted CodeCompanion range follows that
  plugin's explicit compatibility guidance while the lockfile remains the system-wide rollback
  boundary.

## Validation

The implementation must demonstrate:

- warning-only Lazy diagnostics pass while error diagnostics fail;
- dry-run produces no state files or directories;
- another Neovim process prevents an update;
- runtime-smoke and CodeCompanion-health failures both trigger rollback;
- rollback invokes Tree-sitter verification after plugin restoration;
- CodeCompanion is release-ranged and the documentation contains no literal token example;
- the full static, integration, headless, Tree-sitter, health, formatting, and startup-performance
  gates pass.

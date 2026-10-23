# Safe Updates and Rollback

## Policy

There are two independent mechanisms:

1. lazy.nvim's asynchronous checker runs at most once every 86,400 seconds and
   notifies when updates are available. It does not install them.
2. The verified updater may apply updates no more than once every seven days,
   or immediately when manually requested.

A newly installed policy waits a full seven days before its first automatic
update. No updater is scheduled in headless Neovim. Interactive eligibility is
checked asynchronously after startup; network work never occurs on the startup
path. An eligible update is queued and starts as a detached process only after
normal `VimLeavePre`.

No launchd job is installed. Exit-triggered execution avoids login-time work
and does not require sudo. The worker receives the initiating process ID,
waits briefly for it to exit, and refuses to run while another Neovim session
owned by the user is active.

## Eligibility

An update runs only when all of these are true:

- an interactive UI is attached;
- the loaded LazyVim specification and `lazy-lock.json` are valid;
- the Neovim configuration subtree is clean in Git;
- a complete `~/.config/nvim.backup.*` containing `init.lua`,
  `lazy-lock.json`, and `lua/` exists;
- lazy.nvim is idle;
- no updater lock is active;
- the initiating Neovim process has exited and no other Neovim session is
  active;
- the interval has elapsed, unless the request is manual.

The shell worker repeats critical checks before changing anything. It uses
`umask 077`, an atomic directory lock, atomic state writes, and an explicit
lockfile snapshot.

## Update transaction

The worker performs:

1. Pre-update startup validation, including current lazy.nvim specification
   error diagnostics.
2. Timestamped `lazy-lock.json` snapshot.
3. `Lazy! update` and explicit inspection of lazy.nvim task and specification
   errors.
4. Lockfile JSON validation.
5. `Lazy! sync` and another task/specification inspection.
6. Synchronous install/update of all 33 declared Tree-sitter parsers and
   compilation of every shipped query through nvim-treesitter's supported API.
7. Post-update startup and specification validation.
8. Plugin-specification and update-policy regression tests.
9. The real runtime smoke suite for Markdown isolation, CSV immutability,
   split/join, lazy command loading, outline, undo, and task execution.
10. Scoped Lazy, LSP, and Tree-sitter health checks.
11. A loaded CodeCompanion health check without making an API request.
12. Final lockfile validation and a structured result record.

Any failed step restores the snapshot over `lazy-lock.json`, runs
`Lazy! restore`, realigns and validates all required Tree-sitter parsers,
validates startup again, and records whether rollback fully succeeded. A
failed update never advances the success timestamp.

A successful update intentionally leaves `lazy-lock.json` modified so its
revision changes can be reviewed. Because a clean Neovim Git subtree is an
eligibility requirement, that change also prevents another automatic update
until the lockfile is committed or reverted.

## Commands

Recommended:

```vim
:LazySafeUpdate
:LazySafeUpdateStatus
:LazySafeUpdateCancel
```

Equivalent mappings:

```text
<leader>pu  queue a safe update
<leader>ps  show status and log path
```

Built-in maintenance:

```vim
:Lazy
:Lazy sync
:Lazy update
:Lazy check
:Lazy restore
```

Use direct `:Lazy update` only when intentionally bypassing the transaction.

The shell worker can also be inspected without making changes:

```bash
~/.config/nvim/scripts/safe-plugin-update.sh --manual --dry-run
```

Dry-run is side-effect-free: it performs eligibility checks but creates no
state directory, lock, log, snapshot, or timestamp.

## State, logs, and snapshots

All generated files are private local state and remain outside Git:

```text
~/.local/state/nvim/safe-plugin-updates/
├── last-attempt
├── last-success
├── last-result.json
├── last-notified
├── update.lock/
├── logs/<UTC-run-id>.log
└── snapshots/lazy-lock.<UTC-run-id>.json
```

`last-result.json` contains status, mode, timestamps, rollback state, message,
and the exact log/snapshot paths. The next interactive startup reports a new
result once.

## Disable or pause automation

To disable only automatic application of updates, set this before
`config.autocmds` loads, for example in `lua/config/options.lua`:

```lua
vim.g.safe_plugin_updates_enabled = false
```

Manual `:LazySafeUpdate` remains available. Remove the line to re-enable
automatic scheduling. Use `:LazySafeUpdateCancel` to cancel a request already
queued in the current Neovim process.

To disable update-availability notifications as well, change the `checker`
block in `lua/config/lazy.lua` to `enabled = false`.

## Manual lockfile rollback

First close all Neovim processes. Choose the latest known-good snapshot from
`~/.local/state/nvim/safe-plugin-updates/snapshots/`, then:

```bash
cp -p ~/.config/nvim/lazy-lock.json /tmp/lazy-lock.failed.json
cp -p ~/.local/state/nvim/safe-plugin-updates/snapshots/lazy-lock.<run-id>.json \
  ~/.config/nvim/lazy-lock.json
nvim --headless "+Lazy! restore" +qa
nvim --headless +qa
```

The first copy preserves the failed lockfile for diagnosis.

## Full configuration recovery

The pre-upgrade backup is:

```text
/Users/sam/.config/nvim.backup.20260725-023926
```

Prefer Git recovery when only tracked Neovim files need restoration. The
pre-upgrade baseline commit is `a7c2bee`, and the original parent is
`23e1adb`.

For a complete filesystem recovery, preserve the current symlink/config first
and restore the backup as a standalone directory:

```bash
mv ~/.config/nvim ~/.config/nvim.failed.$(date +%Y%m%d-%H%M%S)
cp -a /Users/sam/.config/nvim.backup.20260725-023926 ~/.config/nvim
nvim --headless "+Lazy! sync" +qa
nvim --headless +qa
```

This moves rather than deletes the failed configuration. Because the normal
live path is a symlink into `star-setup`, this recovery intentionally replaces
the symlink with a standalone copy while leaving the repository checkout
untouched.

## Troubleshooting

- “dirty configuration”: review `git status --short -- dotfiles/nvim`; commit
  or intentionally preserve those changes before retrying.
- “missing backup”: verify a timestamped backup contains `init.lua`,
  `lazy-lock.json`, and `lua/`.
- exit status 75: another updater owns the lock, the initiating process did
  not exit in time, or another Neovim session is active. A stale updater lock
  is reclaimed automatically when its recorded process no longer exists.
- parser failure: verify `tree-sitter --version`, a C compiler, `curl`, and
  `tar`; then run `:checkhealth vim.treesitter`.
- failed update: run `:LazySafeUpdateStatus`, open its log, and confirm whether
  `rolled_back` is true in `last-result.json`; rollback also realigns
  Tree-sitter parsers with the restored plugin revision.
- startup still fails after rollback: restore the full backup or use the
  pre-upgrade Git baseline, then run `Lazy! sync`.

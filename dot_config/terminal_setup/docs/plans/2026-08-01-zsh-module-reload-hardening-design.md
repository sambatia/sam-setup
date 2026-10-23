# Zsh Module Reload Hardening Design

Date: 2026-08-01

## Objective

Make `refresh` reload the complete intended Zsh configuration deterministically,
detect module drift before replacing any shell, remove plaintext credential
remnants, and make the active configuration reproducible from chezmoi without
overwriting newer live configuration.

## Current State

- `refresh` safely validates an isolated interactive login Zsh and replaces only
  eligible idle shells.
- Zsh correctly loads `.zshenv`, `.zprofile`, and `.zshrc` for the login,
  interactive refresh path.
- `.zshrc` contains an explicit ordered list of 12 modules, while
  `.zshrc.d` contains a thirteenth unlisted `secrets.zsh` file.
- `zsh-refresh-current` syntax-checks every `*.zsh` file, including unlisted
  files, but does not prove that the login shell sourced each file.
- The active NTFY token is retrieved from macOS Keychain. The same live token is
  also present in plaintext in `secrets.zsh`, an old `.zshenv` backup, and Zsh
  history. The token itself is not present in the managed chezmoi source.
- The live `.zshrc` and `.zshenv` are newer than their clean managed sources.
  A broad `chezmoi apply` would currently overwrite valid live changes.
- Only the refresh module is managed under `dot_zshrc.d`; the other active,
  non-secret modules are local-only.

## Constraints

- Preserve the current module order and the safe Herdr pane-selection behavior.
- Never auto-source an arbitrary new file merely because it has a `.zsh`
  suffix.
- Never print, log, commit, or pass credential values in command arguments.
- Do not revoke or rotate the current NTFY token while external consumers are
  unknown.
- Do not commit, push, or rewrite repository history without explicit approval.
- Preserve unrelated live shell behavior and user changes.

## Considered Approaches

### 1. Explicit manifest with fail-closed validation

Move the ordered module names to one data-only manifest. Make `.zshrc` load
exactly that manifest and make `zsh-refresh-current` independently verify that:

- every entry is a safe basename ending in `.zsh`;
- entries are unique;
- every listed file exists as a regular file;
- every on-disk `.zsh` module is listed; and
- every module passes `zsh -n`.

This is selected. It preserves deterministic ordering, prevents accidental
execution, and makes omissions observable before shell replacement.

### 2. Lexically source every `*.zsh`

This eliminates list maintenance, but a backup, partial file, or stale secret
file becomes executable configuration automatically. The discovered
`secrets.zsh` file demonstrates why this is unsafe.

### 3. Keep the inline list and remove only the orphan

This is the smallest change, but the preflight still cannot distinguish an
intentional local module from an accidentally unlisted one. The same class of
drift can recur silently.

## Architecture

### Module manifest

Create `~/.zshrc.d/.module-order` as a line-oriented, data-only file. Blank
lines and lines beginning with `#` are ignored. Every other line is one module
basename. Absolute paths, path separators, whitespace, glob characters,
duplicates, and non-`.zsh` names are invalid.

The manifest lists all 12 active modules in their current order. The stale
`secrets.zsh` file is not listed.

### Interactive loader

Create a hidden `~/.zshrc.d/.module-loader.zsh` helper and replace the inline
module list in `.zshrc` with a call to it. The helper:

1. requires a readable manifest;
2. parses only valid module basenames;
3. rejects duplicates;
4. requires each listed module to be a non-symlink regular file;
5. sources modules in manifest order;
6. names any module that returns nonzero and stops before later modules; and
7. reports unlisted on-disk `.zsh` files to stderr.

Configuration errors produce concise path-and-reason diagnostics. They do not
execute an unlisted file. A normal interactive shell remains available so the
configuration can be repaired; the refresh worker treats the diagnostic as a
failed preflight and does not replace the live shell.

### Refresh preflight

Add a manifest-validation stage to `zsh-refresh-current` before syntax and
runtime startup checks. The worker invokes the same Zsh loader in explicit
`--validate` mode, which validates without sourcing modules. Keeping one parser
for interactive loading and refresh preflight prevents the two contracts from
drifting and gives focused errors for missing manifests, malformed names,
duplicates, missing modules, non-regular modules, and unlisted modules.

The worker continues to run `zsh -n` and an isolated `zsh -lic` completion
probe. Existing timeout, acknowledgement, clear, and cleanup semantics remain
unchanged.

### Chezmoi ownership

Reconcile the newer live `.zshrc` and `.zshenv` into the chezmoi source only
after secret scanning. Add the module loader, module manifest, and all 12 active
non-secret modules to chezmoi. Preserve `sam-wizard.zsh` as a private-mode
target. Do not add `secrets.zsh`.

Apply only the explicitly changed shell targets. Confirm that the resulting
source and destination states are identical before broadening scope.

### Credential cleanup

Keep macOS Keychain as the canonical NTFY token store. Before cleanup, confirm
the Keychain item is available and that a clean login shell obtains a non-empty
value without printing it.

Then:

- remove the exact orphan `~/.zshrc.d/secrets.zsh` file;
- remove only NTFY token assignment lines from the old `.zshenv` backup;
- remove only history entries containing `NTFY_TOKEN` from `.zsh_history`; and
- verify that the live token no longer appears in those files without printing
  the token.

The token is not rotated or revoked because other consumers are unknown. Token
rotation remains a separate staged operation once consumers can be inventoried.

## Error Handling and Safety

- Manifest validation runs before any shell replacement or pane clearing.
- New unlisted modules fail closed instead of auto-executing.
- A missing listed module produces an actionable error instead of being
  silently skipped.
- A silent nonzero module return becomes an explicit loader diagnostic, and
  `.zshrc` returns before loading later configuration.
- Credential cleanup targets exact files and exact matching records only.
- Command and working-directory logging is removed. The latency probe stores
  only timestamp and duration, uses a private umask, enforces mode `0600`, and
  rotates through a private unpredictable temporary file. Its startup migration
  guard removes the deprecated regular log if an older in-memory hook recreates
  it before that shell is refreshed.
- Security-sensitive UID and mode checks use absolute-path BSD/GNU `stat`
  adapters so the same fail-closed checks work on macOS and Ubuntu CI.
- No secret is written to a temporary file, report, patch, Git diff, or command
  argument.
- No Herdr pane is mutated during validation; only the existing dry-run path is
  exercised automatically.
- No package installation is required.

## Testing

Add focused Bats coverage proving that the worker:

- accepts a complete valid manifest;
- rejects a missing manifest when modules exist;
- rejects an unsafe or duplicate entry;
- rejects a listed module that is missing or not regular;
- rejects an on-disk module absent from the manifest; and
- still accepts a ZDOTDIR with no module directory.

Validate the production configuration with:

- the complete Bats suites;
- ShellCheck and shfmt checks for Bash executables;
- `zsh -n` for startup files and modules;
- a target-name-aware validation of the real managed module inventory;
- disposable Ubuntu 24.04 execution of all Bats and shell-analysis checks;
- `gitleaks git` for repository history and `gitleaks dir` for live targets;
- `git diff --check`, Actionlint, and Typos;
- scoped `chezmoi diff` and source/destination identity checks;
- `zsh-refresh-current --check`;
- `refresh --dry-run --keep-scrollback`; and
- a clean-environment login-shell probe that reports only whether required
  variables and functions exist.

## Documentation

Update the terminal tooling README to document the manifest, its validation
contract, how to add a module, and the failure-recovery command sequence.

## Rollback

Rollback restores the previous `.zshrc`, worker, module ownership set, and
README from the reviewed Git diff, then applies only those targets. The removed
plaintext token copies are intentionally not restored; Keychain remains the
canonical credential source throughout.

## References

- [Zsh startup files](https://zsh.sourceforge.io/Intro/intro_3.html)
- [Current Zsh manual: files](https://zsh.sourceforge.io/Doc/Release/Files.html)
- [chezmoi password-manager integration](https://www.chezmoi.io/user-guide/password-managers/)
- [chezmoi source-state attributes](https://www.chezmoi.io/reference/source-state-attributes/)
- [Apple Platform Security: Keychain data protection](https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web)
- Installed macOS `security(1)` manual for current CLI behavior

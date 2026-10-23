# Professional Zsh Stack Audit Design

**Date:** 2026-08-04

## Objective

Converge the existing macOS Zsh environment on the approved 30-component
baseline without replacing healthy ownership, duplicating integrations, or
weakening the existing fail-closed plugin and module loaders.

## Evidence and root causes

The active stack is `/bin/zsh` with Oh My Zsh, Homebrew-owned plugins,
Starship, chezmoi-managed startup files, and the star-setup `update-all`
orchestrator. All repositories were clean and synchronized before work.

The interrupted-update autocomplete failure is already contained by the
Homebrew-owned HEAD installation and the bounded plugin preflight. The new
audit found five independent gaps:

1. `zsh-completions` is the only approved, non-conflicting missing package.
2. `zsh-syntax-highlighting` is sourced before later widget integrations,
   contrary to its upstream ordering contract.
3. fzf's integration guard is exported. Nested or replacement shells inherit
   `FASTOOZ_FZF_LOADED=1` even though ZLE widgets are process-local, so they
   skip fzf initialization. A real pseudo-terminal reproduced native Ctrl-T
   and Alt-C bindings; removing the inherited marker restored both widgets.
4. The strict module loader used `module_path` as a loop variable, shadowing
   Zsh's special binary-module search array while child modules were sourced.
   The first real fzf load exposed this by preventing `zsh/regex` from loading.
5. Long-lived terminal processes could export removed Homebrew Cellar entries
   through `FPATH`; completion initialization must discard only entries that no
   longer exist before using the inherited search path.

TPM is installed from the official repository, every current plugin worktree
is clean, and TPM ships a documented command-line `bin/update_plugins all`
entry point. `update-all` currently reports TPM but never invokes that safe
noninteractive path.

## Considered approaches

### A. Minimal convergence (selected)

Keep Oh My Zsh, Starship, mise, Homebrew ownership, and the existing module
architecture. Install only `zsh-completions`; add its `fpath` before
zsh-autocomplete/compinit; give fzf a managed module with a behavior-based
idempotency guard; defer syntax highlighting until the end; and add a
fail-closed TPM updater to `update-all`.

This has the smallest state change and directly addresses every reproduced
gap.

### B. Literal checklist installation

Install Antidote, tealdeer, and bottom as well. Rejected because Antidote would
compete with healthy Oh My Zsh ownership, `tealdeer` conflicts with the
installed `tlrc` tldr client, and bottom duplicates the installed btop role.

### C. Broad shell rewrite

Reorder every integration and replace the legacy additions file. Rejected for
this task because it expands risk substantially and could regress carefully
hardened PATH, Keychain, Herdr, and refresh behavior. The selected design
improves ownership at the verified fault boundaries only.

## Selected architecture

- Homebrew remains the sole owner of the baseline binaries and Zsh plugins.
- Oh My Zsh remains the sole framework; no Antidote or Zinit activation is
  added.
- `zsh-completions` is prepended exactly once to `fpath` before
  zsh-autocomplete and Oh My Zsh initialize completion.
- `~/.zshrc.d/fzf.zsh` becomes the explicit fzf owner. It configures fd/bat/eza
  behavior before sourcing official fzf integration, disables fzf Ctrl-R so
  Atuin remains authoritative, checks actual ZLE widgets for idempotency, and
  uses a shell-local compatibility marker only for the legacy additions file.
- Existing guards continue to make Starship, zoxide, direnv, mise, and Atuin
  effective exactly once. The Atuin fallback checks the widget registry rather
  than grepping display text.
- `zsh-syntax-highlighting` is loaded through the existing safety gate after
  every integration and widget definition.
- `update-all` accepts a TPM updater only when its root and script are regular,
  the script is tracked, the worktree is clean, and the origin is exactly the
  official `tmux-plugins/tpm` repository. Dry/check modes plan only; update mode
  executes `all` through the existing bounded runner and records failures.

## Safety and rollback

The authoritative snapshot is
`~/.local/state/zsh-stack-backups/20260804-135815`. Its checksum file covers
every pre-existing file in scope. Its network-independent rollback restores
tracked sources, reapplies `.zshrc`, removes only task-created paths, validates
syntax, and never automatically uninstalls the newly added formula.

Work proceeds in the clean canonical repositories instead of a disposable
worktree because chezmoi deployment and the live `update-all` symlink
intentionally resolve through those canonical paths; the mandatory snapshot
provides isolation and recovery without pointing live configuration at a
temporary branch.

# Professional Zsh Stack Audit Implementation Plan

> Execute test-first and preserve the clean, single-owner architecture.

**Goal:** Install and maintain the one missing non-conflicting package, repair
verified shell integration defects, and prove the live environment is safe,
idempotent, synchronized, and recoverable.

**Stack:** Zsh 5.9, Bats, Homebrew, chezmoi, Starship, Oh My Zsh, fzf, Atuin,
TPM, star-setup update-all.

---

## Task 1: Protect completion and widget ordering with failing tests

**Files:**
- Modify: `dot_config/terminal_setup/tests/zsh-optional-plugin-loader.bats`

1. Add a real Zsh integration test whose fake Homebrew completion is visible
   only when `fpath` is configured before the completion framework.
2. Add a pseudo-terminal fzf test that begins with an inherited exported
   compatibility marker, sources the managed module twice, and asserts one
   source plus active Ctrl-T/Alt-C widgets and preserved Ctrl-R.
3. Extend the production startup behavior test to assert that syntax
   highlighting is registered after all later integrations.
4. Run the focused Bats file and confirm each new assertion fails for the
   expected missing behavior.

## Task 2: Install and configure the shell stack

**Files:**
- Modify: `dot_zshrc`
- Create: `dot_zshrc.d/completion-paths.zsh`
- Create: `dot_zshrc.d/fzf.zsh`
- Modify: `dot_zshrc.d/dot_module-order`
- Modify: `dot_config/terminal_setup/recommended-tools.Brewfile`
- Modify: `dot_config/terminal_setup/README.md`

1. Install only Homebrew `zsh-completions` with Homebrew auto-update disabled.
2. Add its directory to `fpath` before zsh-autocomplete/Oh My Zsh completion.
3. Move fzf configuration/integration to the explicit managed module and
   preserve Atuin Ctrl-R.
4. Replace Atuin's display-text guard with a widget-registry guard.
5. Defer the safety-gated syntax-highlighting load until the end of `.zshrc`.
6. Update the reproducible Brewfile and operational documentation.
7. Run the focused Bats test, Zsh syntax checks, module validation, and
   chezmoi scoped diff/apply.

## Task 3: Add fail-closed TPM update coverage

**Files:**
- Create: `scripts/test/update-all/tpm-integration.bats`
- Modify: `scripts/update-all.zsh`
- Modify: `Docs/Update-All.md`
- Create: `Docs/plans/2026-08-04-update-all-tpm-integration-design.md`
- Create: `Docs/plans/2026-08-04-update-all-tpm-integration.md`

1. Add failing tests for absence, official provenance, regular-file and clean
   worktree gates, dry-run behavior, exact `all` argv, and failure recording.
2. Implement a narrow trusted-TPM resolver and section using the existing
   bounded update runner.
3. Call it once from the existing shell ecosystem section; do not duplicate
   Homebrew package updates or touch dotfiles.
4. Run the focused Bats suite, the complete 243+ Bats/Python update-all suite,
   syntax, lint, formatting, secrets, and deployment checks.

## Task 4: Validate live behavior and idempotency

1. Validate package versions, ownership, architecture, `compaudit`, completion
   discovery, hook counts, and Zsh syntax.
2. Use a real pseudo-terminal to check Ctrl-T, Alt-C, and Atuin Ctrl-R in fresh
   and nested shells.
3. Validate Starship, Atuin daemon, zoxide, a private temporary direnv trust
   fixture, and a private tmux server.
4. Benchmark cold/warm startup and compare against the recorded baseline.
5. Run `update-all` in check/dry mode twice; do not run a broad update while
   unrelated outdated packages are pending.
6. Reapply the exact chezmoi target set and rerun checks to prove no second-run
   change.

## Task 5: Review and synchronize

1. Inspect both diffs and status, scan secrets, and verify rollback checksums.
2. Commit logically scoped changes only after all checks pass.
3. Push explicitly authorized repository changes, verify remote refs and CI,
   and keep the live chezmoi/update-all paths synchronized.
4. Deliver the required 30-row final report and exact final status.

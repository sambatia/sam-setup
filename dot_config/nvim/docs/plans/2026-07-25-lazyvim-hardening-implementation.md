# LazyVim Update Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the audited update-transaction, rollback, concurrency, dry-run, and CodeCompanion
compatibility gaps without expanding the existing LazyVim architecture.

**Architecture:** Keep startup eligibility in Lua and the detached transaction in the existing POSIX
shell updater. Share current Lazy diagnostic interpretation through `config.lazy_validation`, pass
only the parent PID across the process boundary, and keep every post-update validation inside the
transaction so any failure uses the existing rollback path.

**Tech Stack:** Neovim 0.12 Lua, LazyVim 16, lazy.nvim 11.17, POSIX shell, Git, Stylua, ShellCheck.

---

### Task 1: Define the new behavior with failing tests

**Files:**
- Create: `dotfiles/nvim/tests/lazy_validation_spec.lua`
- Modify: `dotfiles/nvim/tests/run.sh`
- Modify: `dotfiles/nvim/tests/updater_integration.sh`
- Modify: `dotfiles/nvim/tests/plugin_spec.lua`
- Modify: `dotfiles/nvim/tests/docs_spec.lua`

**Step 1: Add Lazy diagnostic tests**

Create a focused spec that confirms warning diagnostics are accepted, error diagnostics are rejected,
and diagnostic file/message context appears in assertion failures.

**Step 2: Extend integration fixtures**

Add controlled fake `pgrep` behavior, runtime-smoke and CodeCompanion-health failures, and parser
verification markers. Assert dry-run creates no state path, concurrent Neovim blocks before mutation,
both new validation failures roll back, and rollback verifies parsers after `Lazy! restore`.

**Step 3: Add compatibility and documentation assertions**

Require CodeCompanion `version == "^19.0.0"`, reject a literal Keychain-token example, and require the
new operational guarantees in documentation.

**Step 4: Run tests and observe the expected failures**

Run:

```bash
./dotfiles/nvim/tests/run.sh all
```

Expected: failures for behavior not yet implemented.

### Task 2: Repair Lazy spec validation and process handoff

**Files:**
- Modify: `dotfiles/nvim/lua/config/lazy_validation.lua`
- Modify: `dotfiles/nvim/lua/config/safe_updates.lua`

**Step 1: Implement current diagnostic handling**

Add reusable error extraction, boolean validation, and assertion helpers based on
`lazy.core.config.spec.notifs`, filtering at `vim.log.levels.ERROR`.

**Step 2: Use the shared guard**

Replace the stale `spec.errors` check with `config.lazy_validation.spec_is_valid()`.

**Step 3: Pass the initiating PID**

Set `NVIM_SAFE_UPDATE_PARENT_PID` in the detached `vim.system` environment.

**Step 4: Run focused tests**

Run:

```bash
nvim --headless -u NONE -l dotfiles/nvim/tests/lazy_validation_spec.lua
nvim --headless -u NONE -l dotfiles/nvim/tests/safe_updates_spec.lua
```

Expected: PASS.

### Task 3: Harden the shell transaction and rollback

**Files:**
- Modify: `dotfiles/nvim/scripts/safe-plugin-update.sh`
- Modify: `dotfiles/nvim/tests/updater_integration.sh`

**Step 1: Make dry-run observational**

Move state/log/snapshot creation until after a successful non-dry-run preflight. Ensure prerequisite
failures can report to stderr before state exists.

**Step 2: Enforce session exclusivity**

Validate and briefly wait for the passed parent PID. Reject the update when `pgrep` finds another
user-owned `nvim` process.

**Step 3: Extend post-update validation**

Run `tests/runtime_smoke.lua` and a loaded `checkhealth codecompanion` report through the existing
health error detector.

**Step 4: Repair rollback ordering**

After `Lazy! restore`, invoke `scripts/verify-treesitter.lua`, then perform the final startup check.

**Step 5: Run shell-focused checks**

Run:

```bash
./dotfiles/nvim/tests/updater_integration.sh
shellcheck dotfiles/nvim/scripts/safe-plugin-update.sh
```

Expected: PASS.

### Task 4: Pin CodeCompanion and remove unsafe credential guidance

**Files:**
- Modify: `dotfiles/nvim/lua/plugins/ai.lua`
- Modify: `dotfiles/nvim/lazy-lock.json`
- Modify: `dotfiles/nvim/tests/plugin_spec.lua`

**Step 1: Add the supported compatible release range**

Set `version = "^19.0.0"` on the CodeCompanion spec.

**Step 2: Make the Keychain command interactive**

Use `security add-generic-password ... -w` without a literal token argument.

**Step 3: Synchronize in an isolated Neovim app environment**

Run an isolated `Lazy! sync`, preserving the live configuration and data directories, then validate
the resulting lockfile entry.

**Step 4: Run focused plugin tests**

Run:

```bash
nvim --headless -u NONE -l dotfiles/nvim/tests/plugin_spec.lua
jq -e '.["codecompanion.nvim"].commit and .["codecompanion.nvim"].branch' dotfiles/nvim/lazy-lock.json
```

Expected: PASS.

### Task 5: Document the hardened operations

**Files:**
- Modify: `dotfiles/nvim/README.md`
- Modify: `dotfiles/nvim/docs/plugin-audit.md`
- Modify: `dotfiles/nvim/docs/update-and-rollback.md`
- Modify: `dotfiles/README.md`

**Step 1: Document success and review boundaries**

Explain that successful updates intentionally leave `lazy-lock.json` changed and therefore suppress
further automatic updates until reviewed.

**Step 2: Document failure controls**

Cover side-effect-free dry-run, session exclusivity, runtime and AI health gates, parser realignment
during rollback, and the automation disable switch.

**Step 3: Correct stale inventory language**

Describe CodeCompanion's compatible release range, macOS Keychain lookup, and blink.cmp's native
snippet engine accurately.

**Step 4: Run documentation tests**

Run:

```bash
nvim --headless -u NONE -l dotfiles/nvim/tests/docs_spec.lua
```

Expected: PASS.

### Task 6: Verify the complete result

**Files:**
- Modify only if a failure reveals a defect.

**Step 1: Format and statically inspect**

Run:

```bash
stylua --check dotfiles/nvim/init.lua dotfiles/nvim/lua dotfiles/nvim/tests
shellcheck dotfiles/nvim/scripts/safe-plugin-update.sh dotfiles/nvim/tests/updater_integration.sh
./dotfiles/nvim/tests/run.sh all
```

**Step 2: Run isolated runtime gates**

Run the production headless sync/check, runtime smoke, Tree-sitter verifier, scoped health, and full
health capture in an isolated Neovim app environment.

**Step 3: Compare startup performance**

Capture multiple startup runs and compare their medians against the recorded production baseline.

**Step 4: Inspect safety and diff**

Run:

```bash
git diff --check
git diff --stat
git status --short --branch
gitleaks detect --no-banner --redact
```

Review every changed file and confirm no unrelated work or secrets entered the branch.

### Task 7: Clean obsolete updater artifacts and prepare integration

**Files:**
- No tracked files.

**Step 1: Move only the two audited empty logs to Trash**

Revalidate exact paths, regular-file type, ownership, zero size, and `0600` mode. Move them to a
timestamped folder in `~/.Trash`; do not recursively delete updater state.

**Step 2: Re-run final status checks**

Confirm the source worktree is clean after commits and the original worktree still contains exactly
its pre-existing unrelated changes.

**Step 3: Offer the finishing options**

Use the finishing-a-development-branch workflow. Do not push.

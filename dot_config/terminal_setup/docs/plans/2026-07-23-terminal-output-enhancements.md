# Terminal Output Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a native Catppuccin Mocha Eza theme plus `ov` and `fx` without disturbing existing pagers, shell startup, or unrelated dotfile changes.

**Architecture:** Chezmoi owns the Eza theme and terminal-setup documentation; the existing audit Brewfile owns the two Homebrew formulae. Deployment uses explicit targets and `brew bundle --no-upgrade`, with a timestamped backup and no global shell or pager changes.

**Tech Stack:** Chezmoi, Homebrew Bundle, Eza YAML themes, Bats, Zsh, ShellCheck, shfmt

---

Commits are intentionally omitted because workstation policy prohibits committing without explicit authorization.

### Task 1: Add failing contract tests

**Files:**
- Create: `dot_config/terminal_setup/tests/terminal-output.bats`

**Step 1: Write tests for the intended ownership boundary**

Add tests that require:

- exactly one `brew "fx"` and one `brew "ov"` entry;
- no `vivid` entry;
- a Catppuccin Mocha theme at `Library/Application Support/eza/theme.yml`;
- no `PAGER`, `MANPAGER`, `GIT_PAGER`, `LS_COLORS`, or `EZA_COLORS` assignment in the new managed surface;
- README guidance for tool roles, `NO_COLOR`, TTY behavior, stdout/stderr, opt-in language frameworks, and rollback.

**Step 2: Run the test and verify RED**

Run:

```sh
bats dot_config/terminal_setup/tests/terminal-output.bats
```

Expected: failures for the missing formulae, theme, and documentation.

### Task 2: Add the managed packages and theme

**Files:**
- Modify: `dot_config/terminal_setup/recommended-tools.Brewfile`
- Create: `Library/Application Support/eza/theme.yml`
- Create: `Library/Application Support/eza/LICENSE.eza-themes`

**Step 1: Add the minimal package entries**

Add `brew "fx"` and `brew "ov"` in alphabetical order. Do not add Vivid or language UI frameworks.

**Step 2: Add the official theme**

Copy the official `eza-community/eza-themes` Catppuccin Mocha theme content, record its pinned upstream URL, commit, checksum, and retrieval date in comments without changing its behavior, and preserve the upstream MIT notice in the same directory.

**Step 3: Run the package/theme contract tests**

Run:

```sh
bats dot_config/terminal_setup/tests/terminal-output.bats
```

Expected: package and theme assertions pass; documentation assertions still fail.

**Step 4: Validate Chezmoi mapping and theme parsing**

Run exact source/target mapping checks and execute `eza` with an isolated native theme directory.

### Task 3: Document usage, boundaries, and recovery

**Files:**
- Modify: `dot_config/terminal_setup/README.md`
- Create, repository-only: `.typos.toml`

**Step 1: Add tool guidance**

Document direct `ov` and `fx` examples, why existing Bat/Hunk/jq/yq/qsv roles remain unchanged, and why no global pager is set.

**Step 2: Add the script-output contract**

Document TTY detection, non-empty `NO_COLOR`, plain redirected output, stdout/stderr separation, and explicit override behavior.

**Step 3: Add project-local framework guidance**

List Clack, Textual, Charm, and `ratatui` as opt-in project dependencies, not global workstation packages.

**Step 4: Update package count and rollback**

Change the audit-owned formula count from ten to twelve, add `fx` and `ov` to the rollback command, and document removal of the new Eza theme.

**Step 5: Add the repository spelling exception**

Add only the exact `ratatui` crate identifier to the repository-local Typos allowlist and verify Chezmoi does not expose the hidden control file as a managed target.

**Step 6: Run all Bats tests**

Run:

```sh
bats dot_config/terminal_setup/tests/*.bats
```

Expected: all tests pass.

### Task 4: Create the live rollback record

**Files:**
- Create outside Git: `~/.local/state/terminal_setup/output-enhancements-backup-<timestamp>/`

**Step 1: Capture baseline state**

Record date, OS/architecture, Homebrew prefix, relevant executable versions, installed package state, target existence, hashes, and current Git/Chezmoi status without copying secrets.

**Step 2: Back up exact existing targets**

Copy the current README and Brewfile source/target files. Copy a pre-existing Eza theme only if it appears before deployment.

**Step 3: Write exact recovery instructions**

Include source restoration, explicit `chezmoi apply` targets, theme recovery/removal, and conditional `brew uninstall fx ov` commands.

### Task 5: Merge scoped source changes and preview deployment

**Files:**
- Modify in dirty main checkout: `dot_config/terminal_setup/README.md`
- Modify in dirty main checkout: `dot_config/terminal_setup/recommended-tools.Brewfile`
- Create in dirty main checkout: `Library/Application Support/eza/theme.yml`
- Create in dirty main checkout: `dot_config/terminal_setup/tests/terminal-output.bats`
- Create in dirty main checkout: both plan documents

**Step 1: Recheck user drift**

Compare hashes and Git status to the captured baseline. Stop if any target changed unexpectedly.

**Step 2: Apply only the feature patch**

Merge the README additions around the user's Herdr documentation. Do not replace the dirty README wholesale and do not touch `dot_zshrc` or `dot_zshrc.d`.

**Step 3: Preview exact targets**

Run target-specific `chezmoi diff` for only the README, Brewfile, and Eza theme. Confirm no unrelated target appears.

### Task 6: Install and deploy

**Step 1: Install only missing bundle entries**

Run:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade \
  --file "$HOME/.config/terminal_setup/recommended-tools.Brewfile"
```

Expected: `fx` and `ov` install from Apple Silicon bottles; unrelated formulae are not upgraded.

**Step 2: Apply only the Eza theme and managed documentation targets**

Use explicit absolute target paths. Never run bare `chezmoi apply`.

### Task 7: Verify the final system

**Step 1: Static and source validation**

Run all Bats tests, `zsh -n` on active shell files, ShellCheck/shfmt on relevant shell tests/scripts, Chezmoi doctor/diff/status, and `brew bundle check`.

**Step 2: Runtime smoke tests**

Verify installed versions, Eza theme rendering and plain output, valid/invalid `fx` inputs across supported formats, and valid/invalid `ov` invocations.

**Step 3: Regression and boundary checks**

Confirm prompt/shell syntax, Git pager, MANPAGER, global PAGER, `LS_COLORS`, `EZA_COLORS`, existing package versions, and unrelated file hashes remain unchanged.

**Step 4: Inspect final diffs**

Review isolated and live Git diffs, Chezmoi target diffs, and backup contents. Confirm no secrets or unrelated paths are present.

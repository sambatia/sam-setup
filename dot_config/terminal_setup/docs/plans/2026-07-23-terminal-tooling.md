# Terminal Tooling Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Install the relevant audited terminal tools reproducibly and provide one safe, opt-in repository audit command without modifying existing repositories or drifted terminal configuration.

**Architecture:** A dedicated Brewfile owns only the new packages. A chezmoi-managed Bash script detects applicable tracked files and runs local, read-only checks, while target-sensitive tools remain explicit manual operations. Bats fixtures and fake executables validate behavior without network access or repository mutation.

**Tech Stack:** Homebrew Bundle, chezmoi, Bash, Bats, ShellCheck, shfmt, Git.

---

### Task 1: Preserve the baseline and source documentation

**Files:**
- Create: `dot_config/terminal_setup/docs/plans/2026-07-23-terminal-tooling-design.md`
- Create: `dot_config/terminal_setup/docs/plans/2026-07-23-terminal-tooling.md`

**Step 1: Record the clean source baseline**

Run: `git status --short --branch`

Expected: the isolated `terminal-tooling-upgrade` branch with only the two plan files untracked.

**Step 2: Record deployed drift without exposing file contents**

Run: `chezmoi status --path-style absolute`

Expected: the pre-existing modified state for `.gitconfig`, `.tmux.conf`, `.zshenv`, and `.zshrc`.

**Step 3: Do not commit without explicit authorization**

The workstation policy forbids commits without explicit user authorization. Use status and diffs as review checkpoints until authorization is received; after approval, commit the reviewed change and merge it locally without pushing.

### Task 2: Add and validate the package manifest

**Files:**
- Create: `dot_config/terminal_setup/recommended-tools.Brewfile`

**Step 1: Add the minimal manifest**

Declare the Terraform Linters tap, ten selected formulae, and the official TFLint cask. Keep comments limited to safety-relevant roles.

**Step 2: Validate Brewfile syntax before installation**

Run: `brew bundle list --file dot_config/terminal_setup/recommended-tools.Brewfile`

Expected: all declared formulae and the TFLint cask are parsed and listed.

**Step 3: Preview dependency impact**

Run: `brew bundle check --file dot_config/terminal_setup/recommended-tools.Brewfile`

Expected: nonzero with only the not-yet-installed selected packages reported.

**Step 4: Trust only the official TFLint cask**

Run: `brew trust --cask terraform-linters/tap/tflint`

Expected: Homebrew records trust for this exact cask. This is required because Homebrew blocks third-party casks by default, even when the tap is maintained by the tool's official project.

**Step 5: Install idempotently**

Run: `brew bundle install --file dot_config/terminal_setup/recommended-tools.Brewfile --no-upgrade`

Expected: the selected tools install without upgrading unrelated packages. Homebrew reports 12 satisfied Brewfile dependencies: one tap, ten formulae, and one cask.

**Step 6: Re-run the manifest check**

Run: `brew bundle check --file dot_config/terminal_setup/recommended-tools.Brewfile`

Expected: success with all dependencies satisfied.

### Task 3: Write failing repository-audit tests

**Files:**
- Create: `dot_config/terminal_setup/tests/repo-audit.bats`
- Test target: `dot_local/bin/executable_repo-audit`

**Step 1: Add isolated fixture helpers**

Each test creates a temporary Git repository, commits only fixture files, prepends a temporary fake-tool directory to `PATH`, and cleans up through Bats teardown.

**Step 2: Add behavior tests**

Cover:

- help output exits successfully;
- a path with spaces resolves correctly;
- a non-Git directory fails with an actionable message;
- Git whitespace checking always runs;
- actionlint runs only when a tracked workflow exists;
- typos runs once for a repository;
- shell checks run only for tracked `.sh` files;
- OpenTofu formatting and TFLint run only when tracked `.tf` files exist;
- target-sensitive tools (`hurl`, `wt`, `git absorb`, `dive`, `trip`) are never executed;
- one failed check produces a nonzero final status while remaining applicable checks still run;
- missing optional executables are reported as skips rather than crashes.

**Step 3: Run the tests and verify RED**

Run: `bats dot_config/terminal_setup/tests/repo-audit.bats`

Expected: FAIL because `dot_local/bin/executable_repo-audit` does not yet exist.

### Task 4: Implement the minimal safe audit command

**Files:**
- Create: `dot_local/bin/executable_repo-audit`
- Test: `dot_config/terminal_setup/tests/repo-audit.bats`

**Step 1: Implement argument and repository validation**

Support `repo-audit [PATH]` and `--help`. Resolve the Git top level through `git -C`, reject unreadable/non-Git directories, and never change the caller's directory.

**Step 2: Implement check accounting**

Use small functions to record pass, fail, and skip counts. Continue after individual failures and return nonzero if any executed check fails.

**Step 3: Implement local applicable checks**

Use tracked filenames from `git ls-files` and run:

- `git diff --check HEAD`;
- `actionlint` for `.github/workflows/*.yml` or `.yaml`;
- `typos .`;
- `shellcheck -x` and `shfmt -d` for tracked `.sh` files;
- `tofu fmt -check -recursive` and TFLint for Terraform/OpenTofu directories.
- `qsv validate` for CSV/TSV files;
- Lychee in offline mode for Markdown and HTML links.

Never run target-sensitive commands automatically. Print concise manual follow-up hints when matching Hurl, Kubernetes, Docker, CSV, or documentation files exist.

**Step 4: Run the focused tests and verify GREEN**

Run: `bats dot_config/terminal_setup/tests/repo-audit.bats`

Expected: all tests pass.

**Step 5: Run static analysis**

Run: `shellcheck dot_local/bin/executable_repo-audit`

Expected: zero findings.

Run: `shfmt -d dot_local/bin/executable_repo-audit`

Expected: no diff.

### Task 5: Add the operational runbook

**Files:**
- Create: `dot_config/terminal_setup/README.md`

**Step 1: Document tool roles and overlaps**

Explain which tools are automatic in `repo-audit` and which require explicit targets.

**Step 2: Document safe examples**

Include non-destructive examples for actionlint, typos, Hurl test files, Worktrunk listing, Git Absorb dry inspection, Kubeconform, TFLint, Dive, qsv, Trippy, and Lychee. Clearly label commands that can make network requests, create worktrees, rewrite history, or contact remote services.

**Step 3: Document maintenance and rollback**

Record Brew Bundle verification, normal `update-all` ownership, uninstall commands scoped to the new formulae, and conditional tap removal.

### Task 6: Install managed files without touching drifted targets

**Files:**
- Deploy: `~/.config/terminal_setup/recommended-tools.Brewfile`
- Deploy: `~/.config/terminal_setup/README.md`
- Deploy: `~/.config/terminal_setup/docs/plans/*`
- Deploy: `~/.config/terminal_setup/tests/repo-audit.bats`
- Deploy: `~/.local/bin/repo-audit`

**Step 1: Preview only new targets**

Run `chezmoi --source <worktree> diff` with explicit new target paths.

Expected: changes only for files listed above.

**Step 2: Apply only explicit new targets**

Run `chezmoi --source <worktree> apply` with the five explicit target groups. Do not run an unscoped apply.

Expected: new files appear with `repo-audit` executable and no existing managed target changes.

**Step 3: Verify deployed/source equality**

Run explicit `chezmoi diff` for the new targets.

Expected: no diff.

### Task 7: Perform installation and runtime verification

**Files:**
- Test: deployed commands and fixtures only

**Step 1: Smoke-test every new executable**

Run each tool's version/help command without targets, network operations, Docker images, worktree creation, or Git history changes.

Expected: all commands exit successfully and report the installed release or help text.

**Step 2: Run deployed audit tests**

Run: `bats ~/.config/terminal_setup/tests/repo-audit.bats`

Expected: all tests pass against `~/.local/bin/repo-audit`.

**Step 3: Run a disposable integration fixture**

Create a temporary Git repository containing a harmless workflow, shell file, typo-free text, and formatted OpenTofu file. Run `repo-audit` with network disabled and fake or local-only checks as appropriate.

Expected: applicable checks run, target-sensitive tools remain skipped, and the audit exits zero.

**Step 4: Re-check environment health**

Run: `brew doctor`, `mise doctor`, `zsh -n ~/.zshrc ~/.zprofile ~/.zshenv`, and `brew bundle check --file ~/.config/terminal_setup/recommended-tools.Brewfile`.

Expected: healthy package managers, valid shell configuration, and satisfied manifest.

**Step 5: Inspect final state**

Run: `git status --short`, `git diff --check`, and scoped `chezmoi status`/diff checks.

Expected: only intentional new source files; original deployed drift remains unchanged.

### Task 8: Deliver the final report

Summarize installed versions, created files, test counts, actual command results, preserved drift, security boundaries, exact rollback steps, and any tool behavior that remains intentionally manual.

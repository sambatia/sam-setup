# Refresh Clear-by-Default Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make plain `refresh` clear successful pane output by default while retaining a deliberate scrollback-preserving diagnostic mode.

**Architecture:** The Zsh module selects the clear policy and passes it through the existing controller/worker boundary. The worker clears only after successful startup validation and emits a concealed acknowledgement so Herdr retains reliable completion detection without leaving protocol text visible.

**Tech Stack:** Zsh, Bash 3.2-compatible shell, Bats, Herdr 0.7.5, Chezmoi, ShellCheck, shfmt.

---

### Task 1: Lock the command contract with failing tests

**Files:**
- Modify: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Update the default refresh test**

Assert that plain `refresh` calls the controller with `--apply --clear`, calls the current worker with `--clear`, and replaces the shell last.

**Step 2: Add preservation and conflict tests**

Add tests proving `refresh --keep-scrollback` omits `--clear`, while combining it with `--clear` exits `2` before contacting either executable.

**Step 3: Add acknowledgement presentation tests**

Assert that a successful worker clear wraps the acknowledgement in ANSI conceal/reset sequences, while validation failures are not cleared.

**Step 4: Run focused tests and verify RED**

Run: `bats --filter 'refresh applies|keep-scrollback|conflicting clear|conceals' dot_config/terminal_setup/tests/herdr-refresh.bats`

Expected: failures showing the current preserve-by-default behavior and visible acknowledgement.

### Task 2: Implement the minimal behavior

**Files:**
- Modify: `dot_zshrc.d/herdr-refresh.zsh`
- Modify: `dot_local/bin/executable_zsh-refresh-current`

**Step 1: Change the module policy**

Default to clear, accept `--keep-scrollback`, reject conflicting clear policies, pass `--clear` during normal and dry-run controller selection, and pass it to the current worker only during apply.

**Step 2: Conceal successful clear acknowledgements**

When either clear mode succeeds, emit the derived acknowledgement between `\033[8m` and `\033[0m`. Preserve normal visible acknowledgements when scrollback is retained.

**Step 3: Run focused tests and verify GREEN**

Run the focused Bats filter from Task 1.

Expected: all selected tests pass.

### Task 3: Update user documentation

**Files:**
- Modify: `dot_config/terminal_setup/README.md`
- Modify: `dot_zshrc.d/herdr-refresh.zsh`
- Modify: `dot_local/bin/executable_zsh-refresh-current`

**Step 1: Update help text**

Document clear-by-default behavior, `--keep-scrollback`, compatibility of `--clear`, and failure-output retention.

**Step 2: Update the runbook**

Replace preserve-by-default examples and prose with the approved contract and troubleshooting opt-out.

### Task 4: Verify and deploy

**Files:**
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Deploy: `~/.zshrc.d/herdr-refresh.zsh`
- Deploy: `~/.local/bin/zsh-refresh-current`
- Deploy: `~/.config/terminal_setup/tests/herdr-refresh.bats`
- Deploy: `~/.config/terminal_setup/README.md`

**Step 1: Run source validation**

Run Bats, ShellCheck, shfmt, Zsh syntax, typo, whitespace, and secret checks.

**Step 2: Apply only changed Chezmoi targets**

Use explicit target paths; do not apply unrelated `.zshrc`, Brewfile, Library, or terminal-output work.

**Step 3: Run deployed validation**

Run the deployed Bats suite, a login-shell command-discovery check, startup preflight, and `refresh-dry`.

**Step 4: Execute a real guarded refresh**

Exclude the active Codex pane, refresh all currently eligible panes, require `failed=0`, and follow with a dry-run health scan.

### Task 5: Publish the reviewed follow-up

**Files:**
- Stage only the clear-default design, plan, implementation, tests, and refresh README hunk.

**Step 1: Inspect the final staged diff**

Confirm unrelated working-tree changes remain unstaged.

**Step 2: Commit**

Run: `git commit -m "fix refresh display cleanup"`

**Step 3: Push the existing PR branch**

Run: `git push origin agent/robust-herdr-refresh`

**Step 4: Verify the draft PR**

Confirm the remote head SHA, private repository visibility, and PR state.

# Herdr Refresh Redesign Implementation Plan

> **Clear-policy update:** The original preserve-by-default steps in this historical plan are superseded by `2026-07-23-refresh-clear-default.md`.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the unmanaged, failure-obscuring refresh alias with a tested three-layer subsystem that safely refreshes every eligible Herdr pane and the caller.

**Architecture:** A Zsh function provides stable user-facing commands and owns final parent-shell replacement, a Bash controller owns Herdr discovery and acknowledged cross-pane dispatch, and a Bash worker provides an isolated preflight/clear gate. Chezmoi owns all production files and tests; deployment remains explicitly scoped so unrelated live shell drift is preserved.

**Tech Stack:** Zsh 5.9, Bash 3.2 compatibility, Herdr 0.7.5 stable CLI, jq, Bats, ShellCheck, shfmt, chezmoi, Git.

---

### Task 1: Preserve baseline and establish test harness

**Files:**
- Create: `dot_config/terminal_setup/tests/herdr-refresh.bats`
- Reference: `dot_config/terminal_setup/docs/plans/2026-07-23-refresh-redesign-design.md`

**Step 1: Record source and deployed state**

Run:

```sh
git status --short --branch
chezmoi status --path-style absolute
zsh -lic 'whence -av refresh refresh-dry clear-panes clear-panes-dry'
```

Expected: clean `refresh-redesign` source branch, the existing four drifted targets, and the old aliases.

**Step 2: Add isolated fixture helpers**

Create a Bats setup that uses `mktemp -d`, a temporary `HOME`, fake `herdr`, fake controller/worker executables, JSON fixtures, and a call log. Permanently remove only the validated test-owned temporary directory during teardown so captured fixtures are not retained in Trash.

The fake Herdr command must support `pane list`, `pane process-info`, `pane run`, and `pane wait-output`, with environment variables selecting failure paths.

**Step 3: Add initial RED tests**

Cover these missing contracts first:

- the worker and controller expose help without mutation;
- direct controller execution defaults to dry-run;
- pane-list command failure exits `2` instead of successful zero-pane output;
- invalid pane-list JSON exits `2`;
- the caller supplied through `--exclude-pane` is never dispatched;
- plain refresh preserves scrollback by default.

Run:

```sh
bats dot_config/terminal_setup/tests/herdr-refresh.bats
```

Expected: FAIL because the managed worker, controller, and module do not exist.

**Step 4: Review checkpoint**

Do not commit or push without explicit user authorization. Confirm only the design, plan, and failing test file are new.

### Task 2: Implement the single-shell worker with TDD

**Files:**
- Create: `dot_local/bin/executable_zsh-refresh-current`
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Add worker RED tests**

Use a temporary `ZDOTDIR` to cover:

- `--check` succeeds for a valid interactive startup file;
- `--check` fails and preserves diagnostics for a startup file that returns nonzero;
- an invalid acknowledgement challenge is rejected with exit `2`;
- a derived acknowledgement is printed only after successful preflight;
- `--clear` is opt-in and occurs after preflight;
- unknown arguments fail with usage.

Run the focused Bats filters and verify each new test fails for a missing behavior.

**Step 2: Implement minimal worker**

Implement Bash 3.2-compatible argument parsing for:

```text
zsh-refresh-current [--check] [--clear] [--clear-only]
                    [--challenge SAFE_CHALLENGE] [--timeout-ms N]
```

Requirements:

- `set -u -o pipefail` with explicit status handling;
- validate challenges against `^[A-Za-z0-9._:-]{1,128}$`;
- run a real `/bin/zsh -lic` startup in an isolated subprocess;
- capture startup output in a `mktemp` file with a cleanup trap;
- print captured diagnostics only on failure;
- print only the derived acknowledgement after successful preflight;
- enforce the supplied preflight timeout so late success cannot replace a shell after controller failure;
- return immediately for `--check`;
- clear and emit `ESC[3J` only for `--clear`;
- never replace the parent shell; return success so the interactive parent can execute `/bin/zsh -l`.

**Step 3: Verify GREEN and static quality**

Run:

```sh
bats dot_config/terminal_setup/tests/herdr-refresh.bats --filter 'worker'
shellcheck dot_local/bin/executable_zsh-refresh-current
shfmt -d dot_local/bin/executable_zsh-refresh-current
```

Expected: focused worker tests pass with no static findings or format diff.

### Task 3: Implement discovery and eligibility with TDD

**Files:**
- Create: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Add controller RED tests**

Cover:

- duplicate pane IDs are deduplicated;
- supported current pane-ID formats are accepted and unsafe values rejected;
- only panes whose complete foreground process set is `zsh`/`-zsh` are eligible;
- agents, editors, servers, mixed process groups, and the caller are skipped, while missing process data aborts before mutation;
- labels containing spaces do not split arguments;
- normal output never contains argv, cmdline, or cwd;
- no eligible panes is a successful, explicit no-op when discovery succeeded;
- missing `herdr` or `jq` exits `2`.

Run focused controller tests and verify RED.

**Step 2: Implement read-only controller path**

Support:

```text
herdr-refresh-safe-shell-panes
  [--dry-run|--apply]
  [--clear-only]
  [--exclude-pane ID]
  [--session NAME]
  [--timeout-ms N]
  [--verbose]
```

Direct execution defaults to dry-run. Validate session names, pane IDs, and timeout bounds. Use `herdr pane list` plus `jq -e` for valid JSON, then `herdr pane process-info --pane ID`. Keep discovery, invalid JSON, and unavailable process information distinct in summaries and exit handling.

**Step 3: Verify GREEN and static quality**

Run the focused tests, ShellCheck, and shfmt. Expected: all discovery/eligibility tests pass.

### Task 4: Add acknowledged apply behavior with TDD

**Files:**
- Modify: `dot_local/bin/executable_herdr-refresh-safe-shell-panes`
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Add apply RED tests**

Cover:

- dry-run never invokes `pane run` or `pane wait-output`;
- apply invokes the fixed absolute worker path for each eligible non-caller pane;
- clear mode adds `--clear`, while default apply does not;
- every command receives a unique safe challenge whose derived acknowledgement is absent from terminal input echo;
- dispatch failure increments failures and exits `1`;
- acknowledgement failure or timeout increments failures and exits `1`;
- other eligible panes are still attempted after one failure;
- discovery failure prevents every mutation;
- summary counts discovered, eligible, excluded, skipped, refreshed, and failed panes accurately.

Verify RED before implementation.

**Step 2: Implement dispatch and acknowledgement**

Generate a safe per-run ID from time, PID, and random data. Submit the fixed worker command using `herdr pane run`. Verify completion with a derived `herdr pane wait-output` acknowledgement and bounded timeout. Do not accept arbitrary remote command text.

Start each output wait before its dispatch, run waits concurrently, recheck eligibility immediately before dispatch, track each pane independently, and return `1` for any dispatch or acknowledgement failure.

**Step 3: Verify GREEN**

Run the full controller test group and static checks. Expected: all tests pass and output contains no sensitive fixture command lines.

### Task 5: Implement the Zsh orchestration module with TDD

**Files:**
- Create: `dot_zshrc.d/herdr-refresh.zsh`
- Modify: `dot_zshrc`
- Test: `dot_config/terminal_setup/tests/herdr-refresh.bats`

**Step 1: Add module RED tests**

Launch child Zsh processes with a temporary `HOME` and fake controller/worker commands. Cover:

- `refresh-dry` calls controller dry-run and worker check without exec;
- `refresh` passes `--apply` and the documented `HERDR_PANE_ID` exclusion;
- remote failure prevents current-worker execution and returns nonzero;
- remote success runs the current worker as a child and replaces the parent only after it succeeds;
- `refresh --clear` adds clear to remote and current operations;
- compatibility commands retain clear-only behavior;
- help does not contact Herdr;
- invalid options fail without mutation.

Verify RED.

**Step 2: Implement functions**

Define `refresh`, `refresh-dry`, `clear-panes`, and `clear-panes-dry` as Zsh functions. Use arrays for argument safety, absolute `$HOME/.local/bin` paths, and `command` to avoid alias recursion. Validate `HERDR_PANE_ID` through the controller rather than interpolating it into command strings.

On controller failure, return immediately. On success, run the current worker as a child last and execute `/bin/zsh -l` only after it succeeds. Preserve scrollback unless clear is explicit.

Add only `"$HOME/.zshrc.d/herdr-refresh.zsh"` to the source `dot_zshrc` module list. Do not absorb or apply unrelated live `.zshrc` drift.

**Step 3: Verify GREEN**

Run:

```sh
bats dot_config/terminal_setup/tests/herdr-refresh.bats
zsh -n dot_zshrc dot_zshrc.d/herdr-refresh.zsh
shellcheck dot_local/bin/executable_herdr-refresh-safe-shell-panes dot_local/bin/executable_zsh-refresh-current
shfmt -d dot_local/bin/executable_herdr-refresh-safe-shell-panes dot_local/bin/executable_zsh-refresh-current
```

Expected: complete suite passes with no syntax or static findings.

### Task 6: Document operations and rollback

**Files:**
- Modify: `dot_config/terminal_setup/README.md`
- Modify: `dot_config/terminal_setup/docs/plans/2026-07-23-refresh-redesign-design.md` only if implementation evidence changes a documented decision

**Step 1: Document command contract**

Add examples for `refresh`, `refresh-dry`, `refresh --clear`, `clear-panes`, direct controller dry-run, summary meanings, exit codes, caller handling, and recovery after a preflight failure.

**Step 2: Document ownership and rollback**

List the three managed production targets and exact scoped chezmoi diff/apply commands. Explain how to restore the earlier implementation from Git without applying unrelated `.zshrc` changes.

**Step 3: Validate documentation**

Run `typos` and Lychee offline against the changed documentation. Expected: zero findings.

### Task 7: Scoped deployment and integration validation

**Files:**
- Deploy: `~/.zshrc.d/herdr-refresh.zsh`
- Deploy: `~/.local/bin/herdr-refresh-safe-shell-panes`
- Deploy: `~/.local/bin/zsh-refresh-current`
- Deploy: refresh documentation and tests
- Source-only until drift reconciliation: `dot_zshrc`

**Step 1: Preview exact targets**

Use `chezmoi --source <worktree> diff` with explicit new/replaced targets. Expected: no `.zshrc`, `.zshenv`, `.tmux.conf`, or `.gitconfig` target in the apply set.

**Step 2: Apply exact targets**

Use explicit-target `chezmoi apply`, including `--parent-dirs` only where required. Do not run unscoped apply.

**Step 3: Run deployed tests**

Run the Bats suite against deployed controller/worker/module paths plus ShellCheck, shfmt, and `zsh -n`.

**Step 4: Exercise real safe paths**

Run:

```sh
zsh-refresh-current --check
herdr-refresh-safe-shell-panes --dry-run
zsh -lic 'refresh --help; refresh-dry'
```

Expected: preflight succeeds, real dry-run reports panes without mutation, and user-facing dry-run excludes the caller and performs no pane dispatch.

Do not run real `--apply` automatically while agent panes are active. The fake-Herdr integration suite verifies mutation paths without risking live sessions.

### Task 8: Final verification and delivery

**Step 1: Run complete verification**

Run all Bats tests, ShellCheck, shfmt, Zsh syntax, typos, Gitleaks, Brew Bundle, `brew doctor`, `mise doctor`, scoped chezmoi diff, Git diff checks, and source/deployed equality checks.

**Step 2: Verify preserved state**

Confirm the original four deployed drift entries remain the only unrelated drift and no live pane, repository, task file, credential, or external service was changed.

**Step 3: Inspect final diff**

Confirm only the design, plan, tests, runbook, Zsh module, source module-list line, controller, and worker are changed.

**Step 4: Report**

Provide actual test counts, safe real-dry-run totals, files changed, command behavior, source ownership, security boundaries, rollback steps, remaining risks, and the explicit commit/push authorization boundary.

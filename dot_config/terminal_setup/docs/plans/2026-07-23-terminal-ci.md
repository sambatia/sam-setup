# Terminal Tooling CI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a least-privilege GitHub Actions gate, prove it passes remotely, merge the private draft PR, and clean task-owned worktrees safely.

**Architecture:** A single Ubuntu 24.04 job installs only the cross-platform test dependencies and invokes the repository's existing Bats and static-analysis entry points. The workflow has read-only contents permission, pinned external dependencies, bounded runtime, and no secrets or mutation steps.

**Tech Stack:** GitHub Actions, Ubuntu 24.04, Bats, actionlint 1.7.12, ShellCheck, shfmt, Zsh, GitHub CLI.

---

### Task 1: Add the CI workflow

**Files:**
- Create: `.github/workflows/terminal-checks.yml`

**Step 1: Define safe triggers and permissions**

Trigger pull requests to `main`, pushes to `main`, and manual dispatch. Set `permissions: contents: read`, ref-scoped concurrency with cancellation, and a ten-minute job timeout.

**Step 2: Pin checkout and disable persisted credentials**

Use `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1` (`v7.0.1`) with `persist-credentials: false`.

**Step 3: Install and run checks**

Install Bats, jq, Perl SHA support, ShellCheck, shfmt, and Zsh from Ubuntu packages. Install actionlint v1.7.12 with `go install`, then run both Bats suites, actionlint, ShellCheck, shfmt, Zsh syntax, and Git whitespace validation.

### Task 2: Validate and publish CI

**Files:**
- Test: `.github/workflows/terminal-checks.yml`

**Step 1: Validate locally**

Run actionlint, both Bats suites, ShellCheck, shfmt, Zsh syntax, typo checks, and `git diff --check`.

**Step 2: Commit and push**

Stage only the workflow and CI documentation, commit tersely, and push `agent/robust-herdr-refresh`.

**Step 3: Monitor the real workflow**

Use `gh pr checks --watch` and inspect GitHub Actions logs if any check fails. Do not merge until every reported check succeeds.

### Task 3: Merge and synchronize

**Files:**
- No new files.

**Step 1: Mark the PR ready**

Convert private draft PR #1 to ready-for-review only after CI succeeds.

**Step 2: Squash-merge**

Squash PR #1 into `main` and delete its remote feature branch.

**Step 3: Synchronize local main**

Fetch, switch to `main`, and fast-forward it to `origin/main`. Run the full relevant validation on the merged tree.

### Task 4: Clean task-owned worktrees

**Files:**
- Remove only verified duplicate worktrees and their local branches.

**Step 1: Prove no unique work remains**

Compare each dirty task worktree's changed paths and contents against merged `main`. Stop if any change is not represented or superseded there.

**Step 2: Remove worktrees and branches**

After verification, remove `/Users/sam/.config/superpowers/worktrees/chezmoi/refresh-clear-default-impl` and `/Users/sam/.config/superpowers/worktrees/chezmoi/refresh-redesign`, then delete only their corresponding local branches.

**Step 3: Final audit**

Confirm local `main` is clean and synchronized, deployed refresh files match Chezmoi source, PR #1 is merged, and no task worktrees remain.

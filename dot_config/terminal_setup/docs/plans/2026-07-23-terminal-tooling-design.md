# Terminal Tooling Upgrade Design

Date: 2026-07-23

## Objective

Add the audited terminal tools that match the workstation's demonstrated workloads while preserving existing repositories, shell behavior, chezmoi-managed files, credentials, and external systems.

## Evidence

The workstation already has a mature Ghostty, Zsh, tmux, Homebrew, mise, chezmoi, Git, container, Kubernetes, infrastructure, and security toolchain. Project-level filename counts show active use cases for GitHub Actions, Terraform/OpenTofu, Kubernetes/Helm, Docker/Compose, HTTP collections, and CSV/TSV data.

The deployed `.zshrc`, `.zshenv`, `.tmux.conf`, and `.gitconfig` currently differ from their clean chezmoi source copies. They are therefore out of scope for automated edits or broad `chezmoi apply` operations.

## Considered Approaches

### 1. Install binaries only

This is the smallest change, but it leaves no reproducible package manifest, safe common entry point, test coverage, or maintenance guidance.

### 2. Reproducible installation plus an opt-in safe audit command

Install only relevant, maintained tools through Homebrew; record them in a dedicated Brewfile; provide a chezmoi-managed `repo-audit` command; and document usage and rollback. The command performs local, read-only checks by default and skips operations that need a target, network access, credentials, elevated privileges, Docker image, or executable HTTP scenario.

This is the selected approach because it balances utility, reversibility, and low integration risk.

### 3. Enforce tools through hooks in every repository

This offers stronger enforcement but would modify many unrelated repositories, interact with existing pre-commit and Lefthook policies, and create avoidable compatibility and rollback risk. It is intentionally rejected.

## Components

### Package manifest

`~/.config/terminal_setup/recommended-tools.Brewfile` declares:

- `actionlint`
- `typos-cli`
- `hurl`
- `worktrunk`
- `git-absorb`
- `kubeconform`
- the official `terraform-linters/tap/tflint` cask
- `dive`
- `qsv`
- `trippy`
- `lychee`

Homebrew provides an idempotent installation and upgrade path that already integrates with the workstation's existing update workflow. TFLint's official tap migrated it from a formula to a cask; Homebrew trust is granted only to this exact cask and can be revoked independently.

### Safe repository audit

`~/.local/bin/repo-audit`:

- requires a readable directory and resolves it without changing the caller's working directory;
- uses tracked filenames to select applicable checks;
- keeps default execution local and non-mutating;
- runs Git whitespace checks, actionlint, typos, ShellCheck, shfmt check mode, OpenTofu formatting checks, TFLint, qsv structural validation, and offline Lychee checks where applicable;
- avoids executing Hurl scenarios, tracing network hosts, analyzing unspecified Docker images, running Git Absorb, creating Worktrunk worktrees, or downloading Kubernetes schemas;
- reports skipped capabilities and explicit manual boundaries;
- returns nonzero when an executed check fails and distinguishes failures from skips.

No repository hooks or configuration files are created.

### Tests and runbook

Bats tests use temporary fixture repositories and fake executables to verify applicability detection, failure propagation, paths with spaces, missing tools, and non-execution of target-sensitive tools. A runbook records tool roles, safe examples, update checks, security considerations, and rollback commands.

## Security and Operational Boundaries

- No credentials, tokens, or secret-bearing configuration are read or written.
- No `sudo`, privileged packet capabilities, external messages, deployments, pushes, or pull requests are used. A local commit and fast-forward merge are permitted only after explicit user approval.
- Hurl files are never executed automatically because HTTP scenarios may mutate remote services.
- Trippy is never invoked automatically because it requires a user-selected host and can use privileged packet capabilities.
- Dive is never invoked automatically because it requires a selected local or remote image.
- Worktrunk and Git Absorb receive no automation, hooks, merge configuration, or history-rewriting defaults.
- Kubernetes validation remains manual because schema downloads and project-specific CRDs require explicit policy.
- Existing chezmoi-managed files with drift are not modified or re-applied.

## Validation

Validation includes:

- `brew bundle check` against the dedicated manifest;
- version and help smoke tests for every installed tool;
- Bats tests for `repo-audit`, including expected failures before implementation;
- ShellCheck and shfmt checks for the script;
- a disposable local integration repository;
- final Homebrew and mise health checks;
- scoped chezmoi source/target comparison proving existing drift was preserved;
- final inspection of all created source and deployed files.

## Rollback

Rollback consists of removing only the new Homebrew packages, revoking the exact TFLint cask trust record, removing the dedicated Brewfile, audit command, tests, and runbook from chezmoi and the deployed paths, and optionally removing the Terraform Linters tap if nothing else uses it. Existing shell, tmux, Git, project, and user data remain untouched.
